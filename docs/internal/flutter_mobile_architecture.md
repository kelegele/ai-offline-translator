# Flutter 接入 llama.cpp / STQ1_0 的移动端方案

## 总体原则

推荐方案：
- **Flutter 做 UI**
- **原生层负责 llama.cpp 推理**

不要把高性能推理核心直接做进 Dart 层。

平台目标说明：
- 当前目标不是 Windows 本地高性能推理
- Windows 仅作为开发、文档、目录规范和最小兼容验证环境
- 真实运行路径优先面向 Apple Silicon / ARM 移动端
- HarmonyOS NEXT 不纳入 Flutter 主线，按 ArkTS / ArkUI + NAPI + shared native `translator_engine` 的原生端路线单独规划

## 推荐架构

- Flutter 层：
  - 页面
  - 输入框
  - 语言选择
  - 输出展示
  - 状态与错误提示
- 原生层：
  - 模型加载
  - 推理线程管理
  - token 流式输出
  - 取消推理
  - 内存管理

## 推荐目录草图

```text
ai-offline-translator/
├─ README.md
├─ docs/
├─ third_party/
│  └─ llama.cpp/
├─ flutter_app/
│  ├─ pubspec.yaml
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ translator_page.dart
│  │  ├─ translator_controller.dart
│  │  └─ translator_channel.dart
│  ├─ android/
│  │  └─ app/src/main/
│  │     ├─ java/.../TranslatorChannelHandler.kt
│  │     └─ cpp/
│  │        ├─ CMakeLists.txt
│  │        ├─ translator_jni.cpp
│  │        └─ translator_engine.cpp
│  └─ ios/
│     ├─ Runner/TranslatorChannelHandler.swift
│     └─ Native/
│        ├─ translator_bridge.mm
│        └─ translator_engine.mm
└─ scripts/
   ├─ sync_llama.sh
   ├─ build_android_native.sh
   └─ build_ios_native.sh
```

## Flutter 与原生的接口建议

MethodChannel：
- `importModelFile()`：开发期从文件选择器导入模型到 App 私有目录
- `loadModel(path, nCtx, nThreads)`
- `translate(text, srcLang, dstLang)`
- `cancel()`
- `unloadModel()`
- `getModelStatus()`

EventChannel：
- `onToken`
- `onComplete`
- `onError`
- `onStats`

## 模型策略

MVP 阶段只支持：
- `Hy-MT1.5-1.8B-STQ1_0.gguf`

开发阶段标准路径：
- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`

下载方式：
- `modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`

不建议首版同时支持多个模型格式。

模型在 App 内的落点：
- Android：`files/models/`
- iOS / macOS：`Application Support/ai_offline_translator/models/`

移动端交付策略：
- 开发期允许从 `models/` 手动导入模型文件，但加载路径应尽快切到 App 私有目录
- 发布期优先做首启下载或用户导入，不依赖开发机仓库路径
- 模型导入 / 下载后应做最小文件校验，例如扩展名 `.gguf` 和 GGUF magic header

## 版本要求

移动端 App 内部集成的 llama.cpp 必须包含：
- `PR #22836`

开发阶段标准路径：
- `third_party/llama.cpp/`

初始化脚本会从 `https://github.com/ggml-org/llama.cpp.git` 拉取 `refs/pull/22836/head` 到本地 `pr-22836` 分支。

否则 App 不会识别 `STQ1_0`。

## 原生引擎实现约束

`Hy-MT1.5` 的 chat template 是 jinja 模板。原生引擎必须复用 `llama.cpp/common` 层：

- `common_chat_templates_init`
- `common_chat_templates_apply`
- `common_tokenize`
- `common_sampler_init`
- `common_sampler_sample`
- `common_sampler_accept`
- `common_token_to_piece`

不要用裸 `llama_chat_apply_template` 或手写特殊 token 序列替代官方 common 路线。此前手写 token / 非 jinja 模板路径会稳定产生重复乱码。

Windows 备注：
- 当前 Windows 验证只证明 `STQ1_0` 模型可被 PR 分支加载并完成最小输出
- 当前 Windows 构建未启用 GPU 后端，不作为性能参考
- Windows 运行安全规则见 `llama_windows_safety.md`

## MVP 功能建议

首版只做：
- 模型加载
- 单句翻译
- 流式输出
- 取消
- 错误提示
- 基础速度/状态显示

不要首版就做：
- 通用聊天
- 多模型切换
- 本地 server
- RAG / 知识库
- 复杂插件系统

## HarmonyOS NEXT 关系

HarmonyOS NEXT 不直接沿用本 Flutter 工程作为首选路线。原因：

- Flutter 官方主线支持平台不覆盖 HarmonyOS NEXT 原生端
- HarmonyOS NEXT 原生 App 应使用 ArkTS / ArkUI
- Native bridge 应使用 NAPI，而不是 Android JNI 或 Flutter MethodChannel
- Android `arm64-v8a` `.so` 不能直接作为 HarmonyOS NEXT 原生产物复用

可复用边界：

- 复用 `flutter_app/native/translator_engine/translator_engine.cpp`
- 复用 llama.cpp PR #22836 / STQ1_0 技术路线
- 复用模型导入、下载、App 私有目录、启动自动加载、流式 token 输出等产品流程

详细方案见 `docs/internal/harmonyos_next_plan.md`。
