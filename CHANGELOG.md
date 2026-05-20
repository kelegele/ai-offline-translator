# Changelog

## v0.1.1 - 2026-05-20

### Added

- 扩增 HyMT 1.25bit 官方支持语言列表，覆盖 32 种语言（不含官方 demo 排除的 6 种）。
- 语言选择器和首页语言栏展示语言二字码，例如 `英语 (en)`。

### Changed

- 调整原文与译文输入区比例，提升桌面端翻译工作区可用空间。
- Flutter App 版本更新为 `0.1.1+2`。

### Verified

- macOS: `flutter run -d macos` / release app 翻译验证通过
- `flutter analyze` 无错误
- `flutter test` 全部通过（26/26）
- `flutter build macos --release` 构建通过
- `uv run scripts/safe_llama_smoketest.py` 验证 `Hy-MT1.5-1.8B-STQ1_0.gguf` 可加载并完成受限推理

## v0.1.0 - 2026-05-16

### 重要里程碑

v0.1.0 是首个双平台（macOS + Android）功能完整可用的版本，支持：
- GGUF 模型流式翻译，打字机逐字渲染效果
- 模型下载（ModelScope）、导入、自动检测和加载
- macOS DMG 分发 + Android APK 分发

### Added

- 流式翻译与打字机渲染：每 40ms 输出一个 token，营造「打字感」。
- Android 端 JNI 翻译桥接，通过 `translator_engine` 直接调用 llama.cpp。
- Android 端 ModelScope 模型下载器，支持进度回调、取消、验证。
- Android 端 GGUF 文件选择器导入，将模型拷贝到 App 私有目录。
- Android 沉浸式 edge-to-edge 布局，软键盘不压缩页面。
- 翻译中按钮显示 spinner +「翻译中」状态。
- 复制按钮纯 icon，仅在翻译完成后显示。
- 「了解更多」入口直达关于页面，支持复制微信、点击打开 GitHub。
- App 图标（macOS + Android）和关于页面。
- macOS DMG 安装引导（Finder 窗口布局 + Applications 快捷方式）。
- GitHub Release 自动化发布流程文档。
- `docs/PRD.md`：产品需求文档，记录跨端功能对齐要求。

### Changed

- 打字机延迟从 400ms/字 调整为 40ms/字（30-50ms/token 标准）。
- 模型看板不再支持手填路径，仅支持导入或下载。
- 翻译按钮移至原文与译文之间，全宽。
- 禁用态按钮颜色对齐设计规范。
- App 名称统一为「AI离线翻译」。
- Flutter App 版本更新为 `0.1.0+1`。

### Fixed

- `copyWith(clearError: true, errorMessage: msg)` 导致 errorMessage 被清为 null。
- 模型看板导入后不实时更新模型名。
- macOS 文件选择器线程调度问题。
- Flutter assets 图片路径加载。
- GitHub Release 中文文件名被吞。
- 重复的「清空」按钮。
- 原文输入框内容垂直居中对齐问题。

### Verified

- macOS: `flutter run -d macos` 翻译验证通过，打字机流式正常
- Android: `flutter run -d emulator-5554` 翻译验证通过，流式正常
- `flutter analyze` 无错误
- `flutter test` 全部通过（23/23）
- `flutter build apk --target-platform android-arm64 --release` 构建通过
- `flutter build macos --release` 构建通过

## v0.0.3 - 2026-05-16

（已撤回 - 在未验证 Android 端实际运行的情况下错误发布）

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
