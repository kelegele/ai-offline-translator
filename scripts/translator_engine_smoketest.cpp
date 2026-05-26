#include "translator_engine.hpp"
#include "llama.h"

#include <cstdlib>
#include <iostream>
#include <string>

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "usage: translator_engine_smoketest <model.gguf> [text]\n";
    return 2;
  }

  const std::string model_path = argv[1];
  const std::string text = argc >= 3 ? argv[2] : "hello";

  llama_backend_init();

  TranslatorEngine engine;
  TranslatorEngineConfig config;
  config.model_path = model_path;
  config.n_ctx = 256;
  config.n_threads = 2;
  config.gpu_offload = false;

  if (!engine.load(config)) {
    std::cerr << "load failed\n";
    llama_backend_free();
    return 1;
  }

  std::cout << "load ok\n";
  auto result = engine.translate(text, "英语", "中文");
  if (!result.error.empty()) {
    std::cerr << "translate failed: " << result.error << "\n";
    llama_backend_free();
    return 1;
  }
  if (result.cancelled) {
    std::cerr << "translate cancelled\n";
    llama_backend_free();
    return 1;
  }

  std::cout << "translation: " << result.text << "\n";
  llama_backend_free();
  return 0;
}
