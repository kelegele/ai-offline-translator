#include "translator_engine.hpp"
#include "chat.h"
#include "common.h"
#include "llama.h"
#include "sampling.h"
#include <chrono>
#include <vector>
#include <cstring>

static const int N_PREDICT = 128;
static const int TIMEOUT_SECONDS = 60;

static bool is_complete_utf8(const std::string& text) {
  int expected_continuation = 0;
  for (unsigned char byte : text) {
    if (expected_continuation == 0) {
      if ((byte & 0x80) == 0) {
        continue;
      } else if ((byte & 0xE0) == 0xC0) {
        expected_continuation = 1;
      } else if ((byte & 0xF0) == 0xE0) {
        expected_continuation = 2;
      } else if ((byte & 0xF8) == 0xF0) {
        expected_continuation = 3;
      } else {
        return false;
      }
    } else {
      if ((byte & 0xC0) != 0x80) {
        return false;
      }
      expected_continuation -= 1;
    }
  }
  return expected_continuation == 0;
}

TranslatorEngine::TranslatorEngine() = default;
TranslatorEngine::~TranslatorEngine() { unload(); }

bool TranslatorEngine::load(const TranslatorEngineConfig& config) {
  if (loaded_.load()) { unload(); }
  config_ = config;
  cancelled_.store(false);

  llama_model_params model_params = llama_model_default_params();
  model_params.n_gpu_layers = 0;

  auto* model = llama_model_load_from_file(config.model_path.c_str(), model_params);
  if (!model) { return false; }
  model_ = model;

  llama_context_params ctx_params = llama_context_default_params();
  ctx_params.n_ctx = config.n_ctx;
  ctx_params.n_batch = config.n_ctx;
  ctx_params.n_threads = config.n_threads;
  ctx_params.n_threads_batch = config.n_threads;

  auto* ctx = llama_init_from_model(model, ctx_params);
  if (!ctx) {
    llama_model_free(model);
    model_ = nullptr;
    return false;
  }

  auto templates = common_chat_templates_init(model, "");
  if (!templates) {
    llama_free(ctx);
    llama_model_free(model);
    ctx_ = nullptr;
    model_ = nullptr;
    return false;
  }

  ctx_ = ctx;
  chat_templates_ = templates.release();
  loaded_.store(true);
  return true;
}

void TranslatorEngine::unload() {
  cancelled_.store(true);
  finish_generation();
  if (chat_templates_) {
    common_chat_templates_free(chat_templates_);
    chat_templates_ = nullptr;
  }
  if (ctx_) { llama_free(static_cast<llama_context*>(ctx_)); ctx_ = nullptr; }
  if (model_) { llama_model_free(static_cast<llama_model*>(model_)); model_ = nullptr; }
  loaded_.store(false);
}

bool TranslatorEngine::is_loaded() const { return loaded_.load(); }

TranslatorEngineResult TranslatorEngine::translate(const std::string& text,
                                                    const std::string& source_lang,
                                                    const std::string& target_lang) {
  return translate(text, source_lang, target_lang, {});
}

TranslatorEngineResult TranslatorEngine::translate(
    const std::string& text,
    const std::string& source_lang,
    const std::string& target_lang,
    const std::function<void(const std::string&)>& on_token) {
  auto result = begin_translation(text, source_lang, target_lang);
  if (!result.error.empty()) { return result; }

  while (true) {
    auto token = generate_next_token();
    if (!token.error.empty()) {
      result.error = token.error;
      break;
    }
    if (token.cancelled) {
      result.cancelled = true;
      break;
    }
    if (!token.piece.empty() && on_token) {
      on_token(token.piece);
    }
    if (token.done) { break; }
  }

  result.text = generation_output_text_;
  return result;
}

TranslatorEngineResult TranslatorEngine::begin_translation(
    const std::string& text,
    const std::string& source_lang,
    const std::string& target_lang) {
  TranslatorEngineResult result;
  if (!loaded_.load()) {
    result.error = "模型未加载";
    return result;
  }

  finish_generation();
  cancelled_.store(false);
  auto* ctx = static_cast<llama_context*>(ctx_);
  auto* model = static_cast<llama_model*>(model_);
  std::string user_msg = build_prompt(text, source_lang, target_lang);

  common_chat_templates_inputs inputs;
  inputs.use_jinja = true;
  inputs.add_generation_prompt = true;
  inputs.messages.push_back({"user", user_msg});

  common_chat_params chat_params = common_chat_templates_apply(chat_templates_, inputs);
  if (chat_params.prompt.empty()) {
    result.error = "chat template 生成失败";
    return result;
  }

  pending_tokens_ = common_tokenize(ctx, chat_params.prompt, true, true);
  if (pending_tokens_.empty()) {
    result.error = "tokenization failed";
    return result;
  }

  llama_memory_clear(llama_get_memory(ctx), true);

  common_params_sampling sampling_params;
  sampling_params.temp = 0.7f;
  sampling_params.top_k = 20;
  sampling_params.top_p = 0.8f;
  sampling_params.min_p = 0.0f;
  sampling_params.seed = LLAMA_DEFAULT_SEED;
  sampling_params.no_perf = true;

  common_sampler* smpl = common_sampler_init(model, sampling_params);
  if (!smpl) {
    result.error = "sampler 初始化失败";
    return result;
  }

  sampler_ = smpl;
  generation_tokens_ = pending_tokens_;
  generation_n_past_ = 0;
  generation_tokens_are_prompt_ = true;
  generation_remaining_tokens_ = N_PREDICT;
  generation_output_text_.clear();
  generation_stream_buffer_.clear();
  generation_started_at_ = std::chrono::steady_clock::now();
  generation_active_ = true;
  return result;
}

TranslatorEngineToken TranslatorEngine::generate_next_token() {
  TranslatorEngineToken token_result;
  if (!generation_active_) {
    token_result.done = true;
    return token_result;
  }

  auto* model = static_cast<llama_model*>(model_);
  auto* ctx = static_cast<llama_context*>(ctx_);
  auto* smpl = static_cast<common_sampler*>(sampler_);
  const auto* vocab = llama_model_get_vocab(model);

  if (cancelled_.load()) {
    token_result.cancelled = true;
    token_result.done = true;
    finish_generation();
    return token_result;
  }

  auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
      std::chrono::steady_clock::now() - generation_started_at_).count();
  if (elapsed > TIMEOUT_SECONDS) {
    token_result.error = "推理超时";
    token_result.done = true;
    finish_generation();
    return token_result;
  }

  if (generation_remaining_tokens_ <= 0) {
    if (!generation_stream_buffer_.empty() && is_complete_utf8(generation_stream_buffer_)) {
      token_result.piece = generation_stream_buffer_;
      generation_stream_buffer_.clear();
      token_result.done = true;
      finish_generation();
      return token_result;
    }
    token_result.done = true;
    finish_generation();
    return token_result;
  }

  if (generation_tokens_are_prompt_) {
    for (llama_token prompt_token : generation_tokens_) {
      common_sampler_accept(smpl, prompt_token, false);
    }
    generation_tokens_are_prompt_ = false;
  }

  if (!common_prompt_batch_decode(
          ctx,
          generation_tokens_,
          generation_n_past_,
          config_.n_ctx,
          "",
          false)) {
    token_result.error = "decode error";
    token_result.done = true;
    finish_generation();
    return token_result;
  }

  llama_token new_token = common_sampler_sample(smpl, ctx, -1);
  common_sampler_accept(smpl, new_token, true);
  generation_remaining_tokens_ -= 1;

  if (llama_vocab_is_eog(vocab, new_token)) {
    if (!generation_stream_buffer_.empty() && is_complete_utf8(generation_stream_buffer_)) {
      token_result.piece = generation_stream_buffer_;
      generation_stream_buffer_.clear();
      token_result.done = true;
      finish_generation();
      return token_result;
    }
    token_result.done = true;
    finish_generation();
    return token_result;
  }

  const std::string piece = common_token_to_piece(vocab, new_token, false);
  generation_output_text_ += piece;
  generation_tokens_ = {new_token};

  if (!piece.empty()) {
    generation_stream_buffer_ += piece;
    if (is_complete_utf8(generation_stream_buffer_)) {
      token_result.piece = generation_stream_buffer_;
      generation_stream_buffer_.clear();
    }
  }
  return token_result;
}

std::string TranslatorEngine::generation_output_text() const {
  return generation_output_text_;
}

TranslatorEngineResult TranslatorEngine::do_generate(
    const std::function<void(const std::string&)>& on_token) {
  TranslatorEngineResult result;
  while (true) {
    auto token = generate_next_token();
    if (!token.error.empty()) {
      result.error = token.error;
      break;
    }
    if (token.cancelled) {
      result.cancelled = true;
      break;
    }
    if (!token.piece.empty() && on_token) {
      on_token(token.piece);
    }
    if (token.done) { break; }
  }
  result.text = generation_output_text_;
  return result;
}

void TranslatorEngine::finish_generation() {
  if (sampler_) {
    common_sampler_free(static_cast<common_sampler*>(sampler_));
    sampler_ = nullptr;
  }
  generation_active_ = false;
  generation_tokens_are_prompt_ = false;
  generation_n_past_ = 0;
  generation_remaining_tokens_ = 0;
  generation_tokens_.clear();
  generation_stream_buffer_.clear();
}

void TranslatorEngine::cancel() { cancelled_.store(true); }

std::string TranslatorEngine::status_text() const {
  if (loaded_.load()) return "本地模型已就绪（原生引擎）";
  return "未加载模型";
}

std::string TranslatorEngine::build_prompt(const std::string& text,
                                            const std::string& source_lang,
                                            const std::string& target_lang) const {
  if (source_lang == "中文") {
    return "请将以下内容翻译为" + target_lang + "：\n\n" + text;
  }
  return "Please translate to " + target_lang + ", without additional explanation:\n\n" + text;
}
