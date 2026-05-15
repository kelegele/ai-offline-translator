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
  ctx_params.n_threads_batch = 1;

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
  TranslatorEngineResult result;
  if (!loaded_.load()) {
    result.error = "模型未加载";
    return result;
  }

  cancelled_.store(false);
  auto* ctx = static_cast<llama_context*>(ctx_);

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

  return do_generate();
}

TranslatorEngineResult TranslatorEngine::do_generate() {
  TranslatorEngineResult result;
  auto* model = static_cast<llama_model*>(model_);
  auto* ctx = static_cast<llama_context*>(ctx_);
  const auto* vocab = llama_model_get_vocab(model);
  auto start = std::chrono::steady_clock::now();
  std::string output_text;

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

  auto tokens = pending_tokens_;
  int n_past = 0;
  bool tokens_are_prompt = true;

  for (int i = 0; i < N_PREDICT; ++i) {
    if (cancelled_.load()) {
      result.cancelled = true;
      break;
    }
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::steady_clock::now() - start).count();
    if (elapsed > TIMEOUT_SECONDS) {
      result.error = "推理超时";
      break;
    }

    if (tokens_are_prompt) {
      for (llama_token token : tokens) {
        common_sampler_accept(smpl, token, false);
      }
      tokens_are_prompt = false;
    }

    if (!common_prompt_batch_decode(ctx, tokens, n_past, config_.n_ctx, "", false)) {
      result.error = "decode error";
      break;
    }

    llama_token new_token = common_sampler_sample(smpl, ctx, -1);
    common_sampler_accept(smpl, new_token, true);
    if (llama_vocab_is_eog(vocab, new_token)) { break; }

    output_text += common_token_to_piece(vocab, new_token, false);

    tokens = {new_token};
  }

  common_sampler_free(smpl);
  result.text = output_text;
  return result;
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
