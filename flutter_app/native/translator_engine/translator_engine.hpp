#pragma once
#include <atomic>
#include <chrono>
#include <functional>
#include <string>
#include <vector>

struct llama_model;
struct llama_context;
struct llama_vocab;
struct llama_token_data;
struct common_chat_templates;

struct TranslatorEngineConfig {
  std::string model_path;
  int n_ctx = 256;
  int n_threads = 2;
  bool gpu_offload = false;
};

struct TranslatorEngineResult {
  std::string text;
  bool cancelled = false;
  std::string error;
};

struct TranslatorEngineToken {
  std::string piece;
  bool done = false;
  bool cancelled = false;
  std::string error;
};

class TranslatorEngine {
public:
  TranslatorEngine();
  ~TranslatorEngine();

  bool load(const TranslatorEngineConfig& config);
  void unload();
  bool is_loaded() const;

  TranslatorEngineResult translate(const std::string& text,
                                   const std::string& source_lang,
                                   const std::string& target_lang);
  TranslatorEngineResult translate(const std::string& text,
                                   const std::string& source_lang,
                                   const std::string& target_lang,
                                   const std::function<void(const std::string&)>& on_token);
  TranslatorEngineResult begin_translation(const std::string& text,
                                           const std::string& source_lang,
                                           const std::string& target_lang);
  TranslatorEngineToken generate_next_token();
  std::string generation_output_text() const;
  void cancel();
  std::string status_text() const;

private:
  std::string build_prompt(const std::string& text,
                           const std::string& source_lang,
                           const std::string& target_lang) const;

  TranslatorEngineResult do_generate(const std::function<void(const std::string&)>& on_token = {});
  void finish_generation();

  void* model_ = nullptr;
  void* ctx_ = nullptr;
  void* sampler_ = nullptr;
  common_chat_templates* chat_templates_ = nullptr;
  std::atomic<bool> cancelled_{false};
  std::atomic<bool> loaded_{false};
  bool generation_active_ = false;
  bool generation_tokens_are_prompt_ = false;
  int generation_n_past_ = 0;
  int generation_remaining_tokens_ = 0;
  TranslatorEngineConfig config_;
  std::vector<int> pending_tokens_;
  std::vector<int> generation_tokens_;
  std::string generation_output_text_;
  std::string generation_stream_buffer_;
  std::chrono::steady_clock::time_point generation_started_at_;
};
