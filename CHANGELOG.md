# Changelog

## Unreleased

### Added

- 新增 `docs/PRD.md`，记录模型导入、模型下载、不可手填路径和跨端一致性要求。

## v0.0.2 - 2026-05-16

### Added

- 新增 macOS ModelScope 默认模型下载流程，支持进度显示、取消、GGUF magic 校验和 App 私有目录落盘。
- 新增下载器设计与实现计划文档，记录官方 demo 对齐方案和移动端复用方向。

### Changed

- 移除手填模型路径入口；模型面板仅显示模型名称，完整路径不在界面展示且不可编辑。
- 将 Flutter App 版本更新为 `0.0.2+2`。

### Verified

- `flutter analyze`
- `flutter test`
- `flutter build macos`

## v0.0.1 - 2026-05-16

### Added

- 初始化 Flutter 离线翻译 App 骨架，包含 macOS / Android / iOS 工程目录。
- 新增中文工具型翻译界面，支持模型选择、加载、卸载、翻译、取消和译文复制。
- 新增原文输入限制与计数显示，按有效字符统计，不计空格和符号。
- 新增 macOS GGUF 文件导入流程，将模型复制到 App 私有目录。
- 新增 macOS 原生 `TranslatorBridge` / `TranslatorEngine`，直接链接 `llama.cpp` 静态库。
- 接入 `llama.cpp/common` jinja chat template、tokenize 和 sampler 路线，支持 `Hy-MT1.5-1.8B-STQ1_0.gguf` 最小翻译验证。
- 固化移动端优先技术路线：Flutter UI + shared native `translator_engine` + thin platform bridge。

### Verified

- `flutter analyze`
- `flutter test`
- `flutter build macos`
- 使用真实 `Hy-MT1.5-1.8B-STQ1_0.gguf` smoke test，`Hello` 可翻译为 `你好`。
