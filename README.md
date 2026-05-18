# AI离线翻译

一个开源的离线翻译 App，基于 [Hy-MT1.5](https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF) 大语言模型和 [llama.cpp](https://github.com/ggml-org/llama.cpp) 推理引擎，在手机端本地完成翻译，无需网络。

> **一句话原理**：把一个 440MB 的翻译专用大模型量化到 1.25bit（STQ1_0），压缩到可以在手机上跑的体积，再用 llama.cpp 原生引擎加载推理，Flutter 负责跨平台 UI。

## 它是怎么把大模型跑起来的

### 整体架构

```
┌─────────────────────────────────────────────┐
│              Flutter UI (Dart)              │
│  翻译页面 / 模型管理 / 语言选择 / 状态展示      │
└──────────────────┬──────────────────────────┘
                   │ MethodChannel
┌──────────────────┴──────────────────────────┐
│         Platform Bridge (Swift / Kotlin)     │
│  模型导入下载 / 文件管理 / 线程调度             │
└──────────────────┬──────────────────────────┘
                   │ C++ function call
┌──────────────────┴──────────────────────────┐
│         TranslatorEngine (C++)               │
│  llama.cpp 加载模型 / tokenize / 推理 / 采样   │
└──────────────────┬──────────────────────────┘
                   │ links against
┌──────────────────┴──────────────────────────┐
│    llama.cpp (with PR #22836 for STQ1_0)    │
│    ggml / llama / common (chat template)     │
└─────────────────────────────────────────────┘
```

### 怎么包装 llama.cpp

我们不在 Dart 层直接调 llama.cpp，而是在 native 层做了一个**纯 C++ 翻译引擎头文件** `translator_engine.hpp`：

```cpp
struct TranslatorEngine {
    bool loadModel(const char* model_path);
    void translate(const char* text, char* out, size_t out_size);
    void cancel();
    bool isModelLoaded();
};
```

上层（Flutter MethodChannel → ObjC++ / JNI）只需调这三个方法，完全不感知 llama.cpp 内部细节。macOS 和 Android 共用同一份 `translator_engine.cpp`，无需修改引擎代码。

引擎内部封装了模型加载（`llama_model_load_from_file` → `llama_init_from_model`，n_ctx=256, n_threads=2）、jinja chat template 解析（`common_chat_templates_init` / `common_chat_templates_apply`）、tokenize（`common_tokenize`）、采样和生成循环（`common_prompt_batch_decode` → `common_sampler_sample` → `common_token_to_piece`）。取消通过 `std::atomic<bool>` 标记，推理循环每生成一个 token 就检查一次。

llama.cpp 以**静态库**形式编译，直接链接进 App 包：
- macOS：Xcode 静态链接 arm64 库（`build-lib/`）
- Android：CMake + NDK 交叉编译 arm64-v8a 库（`scripts/build_android_llama.sh` → `build-android/`）

### 怎么在移动端跑起来

**① 模型体积**：Hy-MT1.5 约 440MB（1.25bit STQ1_0 量化）。对比原始 bf16（～7GB），体积缩小约 16 倍，手机存储和内存都扛得住。

**② 上下文窗口**：n_ctx=256。翻译场景不需要长上下文，小窗口显著降低内存和推理延迟。

**③ 独立线程推理**：推理在 `std::thread` 中执行，不阻塞 Flutter UI。取消时设置 atomic flag，推理循环下次检查时立即退出。

**④ 构建即交付**：用户安装的 .apk/.dmg 内含所有推理能力，不需要额外运行时或 CLI。

**⑤ 模型独立管理**：模型不内置在 App 包体里（否则 440MB 太臃肿），用户按需下载/导入到 App 私有目录。App 本体仅 15-30MB。

### 踩过的坑

- **不要手写 prompt**：Hy-MT1.5 的 chat template 是 jinja 格式，必须用 llama.cpp common 层的 chat template 函数。之前手写 token 序列导致输出全是乱码。
- **STQ1_0 需要 PR 分支**：llama.cpp 主线不支持 STQ1_0 量化，必须用 [PR #22836](https://github.com/ggml-org/llama.cpp/pull/22836) 的分支，仓库通过 submodule 固定到该 commit。
- **Android 只用 arm64-v8a**：STQ1_0 的 SIMD 路径只适配 ARM NEON，x86 模拟器无法正确推理。

### 关键参数

## 可以复用什么

如果你想在移动端跑大模型，这个项目里可以直接拿走的东西：

### 1. `translator_engine.hpp / .cpp`

纯 C++ 推理引擎封装，不依赖 Flutter。它封装了 llama.cpp 的模型加载、jinja chat template、tokenize、采样和生成循环。你可以直接把它放进任何移动端项目的 native 层。

关键依赖：
- llama.cpp（需要含 common 模块）
- C++17

### 2. `build_android_llama.sh`

一键构建 llama.cpp arm64-v8a 静态库的脚本，输出 `.a` 文件给 Android CMake 链接。适用于任何需要在 Android 上跑 llama.cpp 的项目。

### 3. `CMakeLists.txt`（Android JNI 部分）

展示了如何把 C++ 引擎、llama.cpp 静态库、JNI 桥接编译成一个 `.so`。

### 4. macOS 桥接模式

`translator_bridge.mm` 展示了 ObjC++ 如何包装 C++ 引擎并暴露给 Swift/Flutter。这个模式可以复用于任何 iOS 项目。

### 5. 平台差异对照

| | macOS | Android | HarmonyOS NEXT（规划） |
|---|---|---|---|
| 语言 | ObjC++ wrapper → C++ | JNI → C++ | ArkTS / ArkUI → NAPI → C++ |
| 编译 | Xcode 静态链接 | CMake + NDK | DevEco Studio + OHOS Native SDK |
| 模型目录 | Application Support | files/models/ | App 私有 models 目录 |
| 文件选择 | NSOpenPanel | FilePicker (Intent) | HarmonyOS Picker |
| 下载 | URLSession | OkHttp | HarmonyOS 网络 API |
| ABI | arm64 only | arm64-v8a only | ARM64 / AArch64 only |

## 规划路线

当前已完成：

- **macOS**：用于桌面体验和快速验证，支持模型导入、下载、加载、流式翻译和 DMG 分发。
- **Android**：移动端主线，支持 arm64-v8a 原生推理、模型导入/下载、沉浸式 UI 和 APK 分发。

下一阶段探索：

- **HarmonyOS NEXT 原生端**：按新平台端处理，不依赖 Android APK 兼容层。计划采用 ArkTS / ArkUI + NAPI + shared native `translator_engine.cpp`，用 OHOS Native SDK 重新编译 llama.cpp。麒麟等鸿蒙手机按 ARM64 / AArch64 方向规划，但必须在真机验证 llama.cpp、`STQ1_0` 和 NAPI 线程模型。

暂不投入：

- **iOS**：不上架 App Store 时只能侧载 .ipa，用户体验和分发成本不适合当前开源小工具阶段。

## 快速开始

### 环境要求

- Flutter SDK
- macOS: Xcode + Command Line Tools
- Android: Android Studio + NDK 27+（仅构建 Android 端需要）

### 初始化

```bash
git clone https://github.com/kelegele/ai-offline-translator.git
cd ai-offline-translator
git submodule update --init third_party/llama.cpp
```

### 构建 macOS

```bash
# 先构建 llama.cpp 静态库
cd third_party/llama.cpp
mkdir -p build-lib && cd build-lib
cmake .. -DLLAMA_CURL=OFF -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_SERVER=OFF
cmake --build . -j$(sysctl -n hw.ncpu) \
  --target llama --target llama-common \
  --target ggml --target ggml-cpu --target ggml-base
cd ../../..

# 构建 Flutter App
cd flutter_app
flutter pub get
flutter run -d macos
```

### 构建 Android

```bash
# 先构建 llama.cpp arm64-v8a 静态库（需要 ANDROID_NDK_HOME）
export ANDROID_NDK_HOME=/path/to/ndk
./scripts/build_android_llama.sh

# 构建 Flutter App
cd flutter_app
flutter pub get
flutter run -d <android-device>
```

### 使用

1. 启动 App 后点击右上角「未加载模型」
2. 选择「下载」从 ModelScope 获取模型，或「导入」选择本地 `.gguf` 文件
3. 下载/导入完成后点击「加载」
4. 输入文字，点击「翻译」

## 项目结构

```
ai-offline-translator/
├── flutter_app/
│   ├── lib/                          # Flutter UI (Dart)
│   │   ├── features/translator/
│   │   │   ├── translator_page.dart  # 主页面
│   │   │   ├── translator_controller.dart
│   │   │   ├── translator_channel.dart
│   │   │   └── ...
│   │   └── design/                   # 设计系统
│   ├── native/translator_engine/     # ⭐ 共用 C++ 推理引擎
│   │   ├── translator_engine.hpp
│   │   └── translator_engine.cpp
│   ├── macos/Runner/
│   │   ├── translator_bridge.mm      # macOS ObjC++ 桥接
│   │   └── TranslatorChannelHandler.swift
│   ├── android/
│   │   └── app/src/main/
│   │       ├── cpp/
│   │       │   ├── CMakeLists.txt    # Android CMake 构建
│   │       │   └── translator_jni.cpp  # JNI 桥接
│   │       └── kotlin/.../
│   │           └── TranslatorChannelHandler.kt
│   └── ...
├── third_party/llama.cpp/            # llama.cpp submodule (PR #22836)
├── scripts/
│   └── build_android_llama.sh        # Android arm64 静态库构建
├── docs/
│   ├── index.html                    # GitHub Pages 发布页
│   ├── public/                       # 发布页截图资源
│   ├── internal/                     # 认知与技术方案文档
│   │   ├── PRD.md
│   │   ├── flutter_mobile_architecture.md
│   │   └── harmonyos_next_plan.md
│   └── superpowers/                  # 计划与规格记录
├── CHANGELOG.md
├── AGENTS.md                         # 开发规范与经验教训
└── DESIGN.md                         # UI 设计规范
```

## 致谢

- [Hy-MT1.5](https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF) — 翻译专用大模型（AngelSlim）
- [llama.cpp](https://github.com/ggml-org/llama.cpp) — 高效 LLM 推理引擎
- [llama.cpp PR #22836](https://github.com/ggml-org/llama.cpp/pull/22836) — STQ1_0 量化格式支持
- [Hy-MT-demo.apk 技术报告](models/AngelSlim/Hy-MT-demo-apk-technical-report.md) — 官方 Demo 逆向分析，指导了原生引擎实现

## License

MIT

## 技术路线

本项目最终目标是移动端离线翻译 App，当前阶段支持 macOS + Android。

**iOS 暂不投入**。不上架 App Store 的情况下，iOS 用户只能通过 Xcode 侧载 .ipa 每 7 天重新签名，体验远不如 Android。需要 iOS 时优先上架 App Store 审核路线，或等待欧盟侧载政策变化。

## 当前版本

v0.1.0 - 首个双平台功能完整可用版本。详情见 [CHANGELOG.md](./CHANGELOG.md)。

## 文档索引

- [CHANGELOG.md](./CHANGELOG.md) - 版本变更历史
- [PRD.md](./docs/internal/PRD.md) - 产品需求文档
- [DESIGN.md](./DESIGN.md) - UI 视觉设计规范
- [flutter_mobile_architecture.md](./docs/internal/flutter_mobile_architecture.md) - Flutter 移动端架构设计
- [harmonyos_next_plan.md](./docs/internal/harmonyos_next_plan.md) - HarmonyOS NEXT 原生端方案
- [llama_pr22836_notes.md](./docs/internal/llama_pr22836_notes.md) - llama.cpp PR #22836 与 STQ1_0 分析
- [models_inventory.md](./docs/internal/models_inventory.md) - 本机模型清单
- [decision_record_2026-05-15.md](./docs/internal/decision_record_2026-05-15.md) - 技术决策记录
