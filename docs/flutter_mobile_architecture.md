# Flutter 接入 llama.cpp / STQ1_0 的移动端方案

## 总体原则

推荐方案：
- **Flutter 做 UI**
- **原生层负责 llama.cpp 推理**

不要把高性能推理核心直接做进 Dart 层。

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

不建议首版同时支持多个模型格式。

## 版本要求

移动端 App 内部集成的 llama.cpp 必须包含：
- `PR #22836`

否则 App 不会识别 `STQ1_0`。

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
