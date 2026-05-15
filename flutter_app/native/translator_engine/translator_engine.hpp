#pragma once
#include <atomic>
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
  void cancel();
  std::string status_text() const;

private:
  std::string build_prompt(const std::string& text,
                           const std::string& source_lang,
                           const std::string& target_lang) const;

  TranslatorEngineResult do_generate();

  void* model_ = nullptr;
  void* ctx_ = nullptr;
  common_chat_templates* chat_templates_ = nullptr;
  std::atomic<bool> cancelled_{false};
  std::atomic<bool> loaded_{false};
  TranslatorEngineConfig config_;
  std::vector<int> pending_tokens_;
};
