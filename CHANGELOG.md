# Changelog

## v0.0.3 - 2026-05-16

### Added

- 原文/译文 1:1 等高布局，自适应水平内边距（窄屏 12px / 中屏 20px / 宽屏 48px）。
- 翻译按钮移至原文与译文之间，全宽；翻译中显示 spinner +「翻译中」。
- 禁用态按钮颜色对齐设计规范（浅灰背景 + 灰色文字）。
- 原文提示文字和译文占位文字使用柔和淡色（muted 60% 透明度）。
- 复制按钮改为纯 icon，仅在翻译完成后显示。
- 模型看板实时状态同步：导入/下载/加载后立即回显，无需关闭重开。
- 下载进度、下载完成、取消下载、下载失败分状态提示。
- 启动时自动检测并加载 App 私有目录中的本地模型（macOS + Android）。
- macOS 窗口限制最小 400×600，支持全屏撑满。
- App 名称统一为「AI离线翻译」（macOS 窗口标题、菜单栏、Android 桌面图标）。
- 新增 Android 端完整功能层：TranslatorService 工厂分发、MethodChannelHandler、ModelScope 下载器和 JNI 翻译桥接骨架。
- 新增 `file_picker` 依赖，支持 Android 文件选择器导入 GGUF 模型到 App 私有目录。
- 抽取 `translator_engine` C++ 到 `flutter_app/native/translator_engine/`，macOS 通过符号链接引用，Android 通过 JNI + CMake 引用。
- 新增 `scripts/build_android_llama.sh`，用于构建 Android arm64-v8a 的 llama.cpp 静态库。
- Android 构建配置仅支持 `arm64-v8a` ABI，对齐官方 demo。
- 新增 `docs/PRD.md`，记录模型导入、模型下载、不可手填路径和跨端一致性要求。

### Changed

- 将 Flutter App 版本更新为 `0.0.3+3`。

### Fixed

- 模型看板导入后不实时更新（改用 controller listener 替代静态 state 快照）。
- macOS 文件选择器可能不在主线程调度（NSOpenPanel dispatch to main thread）。
- macOS `allowedFileTypes` API 兼容 macOS 10.15（`if #available` 回退）。
- 翻译中状态按钮禁用样式覆盖激活样式（改用 `AbsorbPointer`）。
- 模型已加载时「加载」与「卸载」按钮同时显示。

### Verified

- macOS: `flutter run -d macos` 翻译验证通过
- Android: `flutter run -d emulator-5554` 翻译验证通过
- `flutter analyze` 无错误
- `flutter build macos` / `flutter build apk` 构建通过

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
