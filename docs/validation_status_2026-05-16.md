# 2026-05-16 验证状态

## 结论

- macOS 已从 CLI fallback 切回原生 `TranslatorBridge` / `TranslatorEngine`。
- 原生引擎已改用 `llama.cpp/common` 的 jinja chat template、tokenize 和 sampler 路线。
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 已通过受限 native smoke test，`Hello` 可翻译为 `你好。`，未复现重复乱码。
- macOS App 已支持把 GGUF 导入到 App 私有目录：`~/Library/Application Support/ai_offline_translator/models/`。

## 已执行验证

```bash
cmake --build third_party/llama.cpp/build-lib --target llama-common -j$(sysctl -n hw.ncpu)
cd flutter_app && flutter analyze
cd flutter_app && flutter test
cd flutter_app && flutter build macos
```

native smoke test 使用真实模型、`n_ctx=256`、`n_threads=2`、CPU-only，输出：

```text
你好。
```

## 已知事项

- `flutter build macos` 会出现静态库 macOS SDK 版本 warning，当前不阻塞构建。
- 当前 macOS native 路线仍是验证平台；后续 Android/iOS 应复用同一 `translator_engine` 设计，而不是恢复 CLI 模式。
- 当前仅实现本地导入到 App 私有目录；首启下载、断点续传和校验清单仍未实现。
