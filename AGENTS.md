# Repository Guidelines

## 项目结构与模块组织

本仓库当前是离线翻译 App 的规划与文档工作区。核心背景在 `README.md`，补充资料集中在 `docs/`。

- `docs/models_inventory.md`：本机模型清单与兼容性记录。
- `docs/llama_pr22836_notes.md`：`llama.cpp` PR #22836 与 `STQ1_0` 加载说明。
- `docs/flutter_mobile_architecture.md`：计划中的 Flutter UI 与原生推理层架构。

后续实现目录应遵循架构文档：`flutter_app/` 存放 Flutter 代码，`third_party/llama.cpp/` 存放固定版本的原生推理依赖，`scripts/` 存放可重复执行的安装与构建脚本。`third_party/llama.cpp/` 是 Git submodule，固定到 `llama.cpp` `PR #22836` 对应 commit。

## 构建、测试与开发命令

目前尚未提交应用源码或自动化测试。相关目录建立前，文档改动应通过交叉阅读链接文件和检查 Markdown 渲染来验证。

开始实现后，优先在对应目录内执行命令：

- `cd flutter_app && flutter pub get`：安装 Flutter 依赖。
- `cd flutter_app && flutter analyze`：运行 Dart 静态分析。
- `cd flutter_app && flutter test`：运行 Flutter 单元测试和组件测试。
- `cd flutter_app && flutter run`：在已连接设备或模拟器上启动应用。

如后续引入 Python，所有 Python 操作必须通过 `uv` 执行，例如 `uv run`、`uv add` 或 `uv sync`。
即使只使用标准库的内联脚本（如一行的 `uv run python -c "..."`），也必须走 `uv run`，禁止直接调用系统 `python3`。

第三方依赖使用 Git submodule 管理：

- `git submodule update --init third_party/llama.cpp`：初始化 `llama.cpp` submodule。
- `git submodule status`：确认当前 submodule 指针。
- 不要把 `third_party/llama.cpp/` 改回临时 clone；如需更新 PR 指针，应更新 submodule commit 并同步修改 README / setup 脚本中的校验 commit。

### llama.cpp 安全执行规则

- 在 Windows 上，**禁止直接运行交互式** `llama-cli` 做手工验证，优先使用受限脚本：`uv run scripts/safe_llama_smoketest.py`。
- Windows 上默认优先 GPU offload；如果没有明确确认 GPU 可用，禁止运行高负载推理命令。
- 未经明确授权，不要在 Windows 上执行 CPU-only 的长时间模型推理；如必须回退 CPU，只能使用受限参数和超时控制。
- 所有 smoke test 必须满足：非交互、可超时、有限输出、有限线程、有限 `n_ctx`、有限 `n_predict`。
- 新增推理脚本时，必须优先考虑“失败时自动退出、超时 kill、输出上限、资源上限”，避免拖死主机。

## 编码风格与命名约定

Markdown 标题应清晰描述内容，仓库内文件链接使用相对路径。后续 Dart 代码遵循标准 Flutter 格式，使用两个空格缩进，文件名采用 `snake_case.dart`。Dart 类名使用 PascalCase，方法、字段和 channel 名称使用 lowerCamelCase。原生桥接文件应按职责命名，例如 `translator_engine.cpp` 或 `TranslatorChannelHandler.kt`。

## UI 与视觉规范

涉及 Flutter UI、页面布局、组件样式、颜色、字体、间距或交互状态的改动，必须先阅读并遵循 `DESIGN.md`。

- `DESIGN.md` 是当前项目的视觉规范来源，基于 MiniMax 风格。
- 首版 UI 应保持工具型翻译界面，不做营销页或 landing page。
- 使用 `DESIGN.md` 中的颜色、圆角、间距、按钮、输入框和卡片规则作为默认设计系统。
- 如 Flutter 默认字体或平台字体无法直接使用 `DM Sans`，应先保持排版比例和层级一致，再单独讨论字体引入。

## 测试规范

新增功能应同步补充测试。Flutter 测试放在 `flutter_app/test/`，文件名使用 `_test.dart` 后缀。原生推理代码在接入 UI 前，应提供小型、可重复的测试或脚本，覆盖模型加载、取消推理和错误处理。

当前仓库的本地推理验证统一使用：

- `uv run scripts/safe_llama_smoketest.py`
- 或 `./scripts/safe_llama_smoketest.ps1`

不要把交互式终端会话当成自动化验证方式。

## 提交与 Pull Request 规范

当前提交历史使用简短祈使句，例如 `Add Flutter gitignore`。继续保持这种风格：简洁、现在时、每次提交聚焦一个变更。

Pull Request 应包含简要说明、变更路径、已执行的验证，以及模型或运行时假设。`flutter_app/` 建立后，涉及 UI 的 PR 还应附截图或录屏。

## 安全与配置提示

不要提交 `.env`、本地模型二进制文件、构建产物或平台生成文件。除非仓库明确采用大文件存储策略，否则大型 GGUF 模型应保留在 Git 之外。

## 移动端优先路线

本项目最终目标是移动端离线翻译 App。所有推理、模型管理和构建方案都应优先服务 Android/iOS 可落地性，而不是只服务 macOS 桌面验证。

- macOS 只是首个验证平台，用于快速验证 Flutter UI、模型加载、prompt、取消和错误处理。
- 长期技术路线必须收敛到“Flutter UI + shared native `translator_engine` + thin platform bridge”。
- CLI `llama-completion` 只能作为 macOS 开发期 fallback / smoke test，不应作为移动端架构目标。
- 原生引擎实现应参考 `models/AngelSlim/Hy-MT-demo-apk-technical-report.md`：使用 `llama.cpp` common 层的 chat template、sampler、tokenize/token-to-piece 能力，而不是手写不兼容的 prompt/token 序列。
- `third_party/llama.cpp` 必须保持支持 `STQ1_0` 的 PR #22836 兼容路径；更新 submodule 前必须先验证 `Hy-MT1.5-1.8B-STQ1_0.gguf` 可加载并能完成最小翻译。
- Android 首个 native 目标只支持 `arm64-v8a`，与官方 demo 一致；不要优先投入 x86/x86_64 Android ABI。
- 模型应下载或导入到 app 私有目录（Android `files/models/`，iOS/macOS `Application Support/models/`），避免依赖开发机仓库路径。

## 发布与打 Tag 纪律

**铁律：未实际验证通过，不打 tag、不 push release commit。**

- "验证通过"意味着在目标平台上真实运行成功：macOS 要 `flutter run -d macos` 跑通翻译，Android 要 `flutter run -d android` 跑通翻译。
- `flutter analyze` + `flutter test` + `flutter build` 通过 ≠ 功能可用。构建成功只证明编译没报错，不证明运行时正确。
- 缺少目标平台运行环境（如 NDK、设备、模拟器）时，不要打 tag。可以先提交代码，等环境就绪验证通过后再 release。
- 每次打 tag 前，自问："我刚才在目标设备上看到功能正常了吗？"如果答案是否，不要打 tag。

### 2026-05-16 教训

在 Android 端还没有 NDK、没有设备、没有实际编译运行的情况下打了 `v0.0.3` tag 并 push。这违反了"验证后再发布"原则。已回退。

根因：
1. 把"代码写完 + analyze/test/build 通过"等同于"功能完成"。
2. 没有在目标平台实际运行就执行了 release 流程。
3. 被连续输出的节奏带跑，没有停下来做发布前检查。

修正措施：
- release 流程必须包含"在目标平台实际运行验证"步骤。
- 如果环境不满足，可以提交代码，但停留在"开发中"状态，不打 tag。

### v0.0.3 开发过程中的教训

1. **`showModalBottomSheet` 传入 state 快照不会随父组件更新**。Bottom sheet 有独立的 widget 树，父组件 `setState` 不会触发 sheet 重建。必须传入 `ChangeNotifier` 引用并在 sheet 内 `addListener`，才能实现实时状态同步。

2. **`FilledButton.onPressed = null` 会强制使用 disabled 样式**。即使手动设置 `backgroundColor`，`onPressed: null` 也会覆盖为系统 disabled 色。需要保持活跃外观但禁止点击时，用 `AbsorbPointer` + `onPressed: () {}` 替代。

3. **macOS `NSOpenPanel` 必须在主线程调用**。Flutter MethodChannel 回调不一定在主线程，`NSOpenPanel.begin()` 在非主线程调用可能导致文件选择器不弹出或行为异常。

4. **macOS `allowedFileTypes` 在 11.0 后废弃**。应使用 `allowedContentTypes` + `UTType`，但需 `if #available(macOS 11.0, *)` 兼容 10.15 deployment target。

5. **UI 改动后确认用 hot reload 而非重新 build**。hot reload（按 `r`）即可刷新 UI，不需要 `flutter build` 或完全重启。如果 hot reload 无变化，再尝试 hot restart（按 `R`）。

6. **布局从 `CustomScrollView` + slivers 切换到 `Column` + `Expanded` 时**，`TextField` 需要 `expands: true` + `minLines/maxLines: null` 才能撑满父容器，否则还是固定行高。

7. **Android 沉浸式需要三层配合**：`SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`（Flutter）+ `styles.xml` 透明状态栏/导航栏（Android 原生）+ 自行处理 `MediaQuery.padding`。只做一层不够。

8. **Android 软键盘不要用 `adjustResize`**。翻译工具型 App 键盘拉起时页面不应被压缩，用 `adjustNothing`（AndroidManifest）+ `resizeToAvoidBottomInset: false`（Scaffold）。

9. **Android 必须声明 `INTERNET` 权限**。Flutter 默认不自动添加，网络请求（下载模型）会静默失败。

10. **Dart 字符串插值 `\$` 在 Python 脚本中会被转义**。用 Python 生成 Dart 代码时，`$variable` 会被 Python 解析。应该用硬编码字符串或 `\\$` 转义，避免运行时显示原始 `$value`。

11. **GitHub Release 文件名必须用英文**。中文文件名会被 GitHub 替换为 `.`，导致下载链接不可读。统一用 `AI-Offline-Translator-v<版本号>-<平台>.<ext>`。

12. **Flutter assets 路径不支持 `../` 上级目录引用**。`pubspec.yaml` 的 assets 必须在 `flutter_app/` 目录内，否则图片加载不出来。

1. **`showModalBottomSheet` 传入 state 快照不会随父组件更新**。Bottom sheet 有独立的 widget 树，父组件 `setState` 不会触发 sheet 重建。必须传入 `ChangeNotifier` 引用并在 sheet 内 `addListener`，才能实现实时状态同步。

2. **`FilledButton.onPressed = null` 会强制使用 disabled 样式**。即使手动设置 `backgroundColor`，`onPressed: null` 也会覆盖为系统 disabled 色。需要保持活跃外观但禁止点击时，用 `AbsorbPointer` + `onPressed: () {}` 替代。

3. **macOS `NSOpenPanel` 必须在主线程调用**。Flutter MethodChannel 回调不一定在主线程，`NSOpenPanel.begin()` 在非主线程调用可能导致文件选择器不弹出或行为异常。

4. **macOS `allowedFileTypes` 在 11.0 后废弃**。应使用 `allowedContentTypes` + `UTType`，但需 `if #available(macOS 11.0, *)` 兼容 10.15 deployment target。

5. **UI 改动后确认用 hot reload 而非重新 build**。hot reload（按 `r`）即可刷新 UI，不需要 `flutter build` 或完全重启。如果 hot reload 无变化，再尝试 hot restart（按 `R`）。

6. **布局从 `CustomScrollView` + slivers 切换到 `Column` + `Expanded` 时**，`TextField` 需要 `expands: true` + `minLines/maxLines: null` 才能撑满父容器，否则还是固定行高。

## 发布流程

### 构建发布包

1. 确认两个平台都已实际运行验证通过
2. 构建产物不入 Git，只上传到 GitHub Release

**Android APK：**

```bash
cd flutter_app
flutter build apk --target-platform android-arm64 --release
# 产物：flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

**macOS DMG：**

```bash
# 1. 构建 .app
cd flutter_app
flutter build macos --release
# 产物：flutter_app/build/macos/Build/Products/Release/ai_offline_translator.app

# 2. 打包 DMG（重命名 app、设置 Finder 窗口大小和图标布局）
rm -rf /tmp/dmg-temp; mkdir -p /tmp/dmg-temp
cp -R flutter_app/build/macos/Build/Products/Release/ai_offline_translator.app "/tmp/dmg-temp/AI离线翻译.app"
ln -sf /Applications /tmp/dmg-temp/Applications
hdiutil create -volname "AI-Offline-Translator" -srcfolder /tmp/dmg-temp -ov -format UDRW -fs HFS+ /tmp/ai-translator-raw.dmg
hdiutil attach /tmp/ai-translator-raw.dmg -readwrite -noverify -noautoopen -quiet
osascript -e 'tell application "Finder"
  tell disk "AI-Offline-Translator"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {260, 180, 740, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 80
    set position of item "AI离线翻译.app" of container window to {160, 180}
    set position of item "Applications" of container window to {360, 180}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell'
sync; sleep 2; hdiutil detach "/Volumes/AI-Offline-Translator" -quiet; sleep 2
hdiutil convert /tmp/ai-translator-raw.dmg -format UDZO -o AI-Offline-Translator-v<版本号>-macos.dmg -ov
rm -f /tmp/ai-translator-raw.dmg; rm -rf /tmp/dmg-temp
```

### 创建 GitHub Release

### Release 文件命名规范

**必须使用英文文件名**，GitHub Release 会吞掉中文字符。统一格式：

```text
AI-Offline-Translator-v<版本号>-android-arm64.apk
AI-Offline-Translator-v<版本号>-macos.dmg
```

示例：

```text
AI-Offline-Translator-v0.0.3-android-arm64.apk
AI-Offline-Translator-v0.0.3-macos.dmg
```

### 创建 GitHub Release

```bash
# 打 tag
git tag -a v<版本号> -m "v<版本号>: 简要描述"
git push origin v<版本号>

# 创建 Release 并上传安装包
gh release create v<版本号> \
  "AI-Offline-Translator-v<版本号>-android-arm64.apk" \
  "AI-Offline-Translator-v<版本号>-macos.dmg" \
  --title "v<版本号> - 标题" \
  --notes "更新内容说明"
```

### macOS 分发说明

- 未签名的 `.dmg`，用户首次打开需要右键 → 打开（绕过 Gatekeeper）
- 不上架 App Store，通过 GitHub Releases 分发

### Android 分发说明

- 自签名 debug APK，不上架 Google Play
- 仅支持 `arm64-v8a`

## Android ABI 约束

- **禁止 x86 / x86_64 ABI**。只支持 `arm64-v8a`。
- 模拟器也必须使用 ARM64 系统镜像（如 `system-images;android-34;google_apis;arm64-v8a`），不允许使用 x86_64 镜像。
- 如果需要模拟器验证，优先使用 Android Studio 创建 Apple Silicon 原生 ARM64 AVD，或使用真机。
