# ai-offline-translator

离线翻译 App 项目工作目录。当前阶段以文档、模型验证和移动端架构准备为主。

## 当前结论

- `llama.cpp` 的 `PR #22836` 支持 `STQ1_0`
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 已在作者本机成功加载并完成翻译推理
- `Hy-MT1.5-1.8B-2bit.gguf` 当前与本地 `pr-22836` loader / writer 组合不兼容

补充说明：

- 当前项目目标**不是在 Windows 上做高性能运行**
- Windows 当前主要用于文档、目录规范、模型下载和最小兼容验证
- 更贴近目标的平台是 Apple Silicon / ARM 移动端

## 一键初始化

Windows PowerShell:

```powershell
.\scripts\setup.ps1
```

macOS / Linux:

```bash
./scripts/setup.sh
```

初始化会执行：

- 使用 `uv tool install modelscope` 安装 `modelscope` CLI（如本机未安装）
- 使用 `modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF` 下载模型
- 初始化 Git submodule `third_party/llama.cpp/`
- 校验 `third_party/llama.cpp/` 固定在 `PR #22836` 对应 commit：`7ef6976b218cfce6158165f4c63a094acb70e707`

如果不运行 setup 脚本，也可以单独初始化第三方依赖：

```bash
git submodule update --init third_party/llama.cpp
```

## 本地目录约定

```text
ai-offline-translator/
├─ models/                  # 本地模型缓存，不提交大文件
├─ third_party/llama.cpp/    # llama.cpp submodule，固定到 PR #22836 commit
├─ scripts/                  # 初始化、下载和构建脚本
└─ docs/                     # 项目文档
```

MVP 推荐模型：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`

模型文件不随仓库提交。大型 `.gguf`、`.bin`、`.safetensors` 和 `.apk` 文件由 `.gitignore` 排除。

## Flutter App

Flutter app 骨架位于 `flutter_app/`。

当前范围：

- 已生成 Android、iOS、macOS 工程目录
- 首轮验证目标为 macOS
- translator feature 已支持通过 macOS 文件选择器导入 GGUF 到 App 私有目录，也支持从 ModelScope 下载默认模型
- 模型选择不支持手填路径；界面只显示模型名称，真实路径仅保存在 App 内部状态
- macOS 当前通过 `MethodChannel` 调用原生 `TranslatorBridge` / `TranslatorEngine`，直接链接 `llama.cpp` 与 `llama-common`
- 原生引擎使用 `llama.cpp/common` 的 jinja chat template、tokenize、sampler 能力，避免手写 prompt token 序列导致乱码
- Android 端已完成 MethodChannelHandler、ModelScope 下载器、`file_picker` 导入和 JNI 翻译桥接骨架
- 原生 C++ `translator_engine` 已抽取到 `flutter_app/native/translator_engine/`，macOS 和 Android 共用
- Android JNI 编译需要先构建 llama.cpp arm64-v8a 静态库：`scripts/build_android_llama.sh`

常用命令：

```bash
cd flutter_app
/Users/fh/Projects/Flutter/flutter/bin/flutter pub get
/Users/fh/Projects/Flutter/flutter/bin/flutter test
/Users/fh/Projects/Flutter/flutter/bin/flutter analyze
/Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

macOS 真推理当前使用本机已构建的 `llama.cpp` 静态库：

```bash
cmake --build third_party/llama.cpp/build-lib --target llama-common -j$(sysctl -n hw.ncpu)
cd flutter_app
/Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

启动后可点击“导入模型”选择本地 GGUF，或点击“下载模型”从 ModelScope 获取默认模型。App 会把模型保存到私有目录：

```text
~/Library/Application Support/ai_offline_translator/models/
```

界面只显示模型文件名，不显示完整路径，也不提供可编辑路径输入框。选择或下载完成后，再点击“加载模型”和“翻译”。当前实现优先安全验证，不启用 Metal offload。

## 建议路线

- 使用 `Hy-MT1.5-1.8B-STQ1_0.gguf`
- 推理层基于包含 `PR #22836` 的 `llama.cpp`
- App 方案优先采用“Flutter UI + shared native translator_engine + thin platform bridge”
- 模型优先进入 App 私有目录，避免依赖开发机仓库路径
- 平台优先级以 Apple Silicon / ARM 移动端为主，不以 Windows 本地高性能推理为目标

## 安全 smoke test

不要在 Windows 上直接运行交互式 `llama-cli` 做验证。请使用受限脚本，避免 CPU/RAM 被长时间占满：

```powershell
.\scripts\safe_llama_smoketest.ps1
```

等价的 `uv` 命令：

```powershell
uv run .\scripts\safe_llama_smoketest.py
```

默认策略：

- 非交互执行，stdin 关闭
- 60 秒超时，超时自动 kill
- 输出超过 64 KiB 自动 kill
- 默认 `n_ctx=256`、`n_predict=16`、`threads=2`
- Windows 默认要求 GPU offload；如要测试受限 CPU fallback，必须显式加 `--allow-cpu`

示例：

```powershell
.\scripts\safe_llama_smoketest.ps1 -AllowCpu -PrintCommand
```

CPU fallback 只用于最小加载验证，不用于性能测试。

## 资料

- `docs/models_inventory.md`：模型清单与当前结论
- `docs/PRD.md`：离线翻译 App 产品需求与跨端行为约束
- `docs/llama_pr22836_notes.md`：`llama.cpp` PR #22836 与 `STQ1_0` 加载说明
- `docs/flutter_mobile_architecture.md`：Flutter UI 与原生推理层架构
- `docs/llama_windows_safety.md`：Windows 上运行 llama.cpp 的安全规则
- `docs/validation_status_2026-05-15.md`：本轮验证状态、遇到的问题和已做调整
- `docs/validation_status_2026-05-16.md`：原生 common 引擎、App 私有模型目录和 macOS 构建验证
- `docs/decision_record_2026-05-15.md`：当前阶段的短决策记录
