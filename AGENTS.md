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
