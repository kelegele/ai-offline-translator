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

### 关键技术点

**1. 为什么选 STQ1_0 量化**

原始 GGUF 模型约 440MB（1.25bit 量化），手机端加载完全可行。但这个量化格式（STQ1_0）不在 llama.cpp 主线，需要 [PR #22836](https://github.com/ggml-org/llama.cpp/pull/22836) 才能识别和加载。

**2. 推理引擎的核心流程**

`TranslatorEngine`（C++）做了这些事：

1. **加载模型**：`llama_model_load_from_file()` → `llama_init_from_model()`，n_ctx=256, n_threads=2
2. **解析 chat template**：`common_chat_templates_init()` 解析模型自带的 jinja 模板（Hy-MT1.5 用的是 jinja 格式）
3. **构建 prompt**：`common_chat_templates_apply()` 把用户消息套进模板，生成完整 prompt
4. **tokenize**：`common_tokenize()` 将 prompt 转为 token 序列
5. **推理循环**：`common_prompt_batch_decode()` → `common_sampler_sample()` → `common_token_to_piece()`，逐 token 生成，直到遇到 EOS 或超过 128 token
6. **取消**：通过 `atomic<bool>` 标记，推理循环每轮检查

> ⚠️ **踩过的坑**：不要手写 prompt 或手动拼接 special tokens。Hy-MT1.5 的 chat template 是 jinja 格式，必须用 `llama.cpp/common` 的 chat template 系列函数处理。之前手写 token 序列导致输出全是乱码（重复字符）。

**3. 平台桥接方式**

| 平台 | 桥接层 | 调用方式 |
|------|--------|---------|
| macOS | `TranslatorBridge` (ObjC++) | 直接 C++ 函数调用 |
| Android | `translator_jni.cpp` (JNI) | JNI native method |

两个平台共用同一份 `translator_engine.cpp`，只是桥接层不同。

**4. 模型管理**

- 模型不内置在 App 包里，用户通过「导入」或「下载」获取
- 下载源：ModelScope（`https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/`）
- 模型保存到 App 私有目录：
  - Android: `files/models/`
  - macOS/iOS: `Application Support/ai_offline_translator/models/`
- 启动时自动扫描本地已有模型，找到就自动加载

**5. 构建方式**

| 平台 | llama.cpp 集成方式 |
|------|-------------------|
| macOS | Xcode 直接链接静态库（`build-lib/` 目录） |
| Android | CMake 链接预编译的 arm64-v8a 静态库（`build-android/` 目录） |

Android 构建需要先用 `scripts/build_android_llama.sh` 编译 llama.cpp 的 arm64 静态库。

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

| | macOS | Android |
|---|---|---|
| 语言 | ObjC++ wrapper → C++ | JNI → C++ |
| 编译 | Xcode 静态链接 | CMake + ndk-build |
| 模型目录 | Application Support | files/models/ |
| 文件选择 | NSOpenPanel | FilePicker (Intent) |
| 下载 | URLSession | OkHttp |
| ABI | arm64 only | arm64-v8a only |

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
│   ├── PRD.md                        # 产品需求
│   ├── flutter_mobile_architecture.md
│   └── ...
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
