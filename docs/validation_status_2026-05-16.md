# 2026-05-16 验证状态

## 结论

- macOS 已从 CLI fallback 切回原生 `TranslatorBridge` / `TranslatorEngine`。
- 原生引擎已改用 `llama.cpp/common` 的 jinja chat template、tokenize 和 sampler 路线。
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 已通过受限 native smoke test，`Hello` 可翻译为 `你好。`，未复现重复乱码。
- macOS App 已支持把 GGUF 导入到 App 私有目录：`~/Library/Application Support/ai_offline_translator/models/`。
- macOS App 已实现 ModelScope 默认模型下载入口，下载目标同为 App 私有模型目录。
- 模型选择不再支持用户手填路径；界面只显示模型名称，完整路径仅保存在内部状态。

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
- 断点续传和校验清单仍未实现；当前下载器支持普通下载、取消和基础 GGUF 校验。
- 440MB 级真实网络下载仍需在 App 内手动完整跑通一次，确认 ModelScope 当前链路稳定。
