# Hy-MT-demo.apk 逆向技术报告

> 分析对象：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT-demo.apk`  
> 分析日期：2026-05-15  
> 分析方式：静态分析；未安装、未运行 APK；未执行模型推理。

## 1. 摘要

`Hy-MT-demo.apk` 是一个 Android 离线翻译 Demo，包名为 `com.tencent.hunyuan.angelslim`。应用采用 Kotlin/Android 原生 UI，内置一个 JNI 推理封装库 `libai-chat.so`，并随包携带 `llama.cpp` / `ggml` 相关 native so，用于加载外部下载到应用私有目录的 GGUF 模型。

Demo 本身不内置 440MB 级 GGUF 模型，而是通过 ModelScope URL 下载模型到应用私有目录 `files/models/`。主界面负责模型下载、模型选择、源/目标语言选择与翻译；另有一个 `PROCESS_TEXT` / `SEND` 入口作为系统文本分享/选中文本弹窗翻译。

对本项目有价值的结论：

- UI/业务层是普通 Android 原生实现，不是 Flutter。
- 推理层可抽象成 `InferenceEngine`：`loadModel`、`setSystemPrompt`、`sendUserPrompt`、`cleanUp`、`destroy`。
- native 层基于 `llama.cpp`，通过 JNI 暴露初始化、加载模型、处理 system/user prompt、逐 token 生成、卸载和关闭。
- APK 仅打包 `arm64-v8a` 的完整推理库；`armeabi-v7a`、`x86`、`x86_64` 只看到 `libdatastore_shared_counter.so`，不具备完整推理能力。
- 模型文件名与本项目下载的上游文件名不同：APK 内部期望保存名为 `HY1.8B-MT-1.25bit.gguf`，下载 URL 指向上游 `Hy-MT1.5-1.8B-1.25bit.gguf`。

## 2. APK 基本信息

### 2.1 Manifest

关键字段：

- package：`com.tencent.hunyuan.angelslim`
- versionCode：`1`
- versionName：`1.0`
- minSdkVersion：`26`
- targetSdkVersion：`36`
- compileSdkVersion：`36`
- application class：`com.tencent.hunyuan.angelslim.App`
- theme：`@style/Theme.TranslateApp`
- native libs：`android:extractNativeLibs="true"`

权限：

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- 自定义 signature 权限：`com.tencent.hunyuan.angelslim.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

Activity：

- `com.tencent.hunyuan.angelslim.MainActivity`
  - `exported=true`
  - Launcher 入口
- `com.tencent.hunyuan.angelslim.TranslatePopupActivity`
  - `exported=true`
  - `launchMode=singleInstance`
  - `excludeFromRecents=true`
  - 支持 `android.intent.action.PROCESS_TEXT`，`text/plain`
  - 支持 `android.intent.action.SEND`，`text/plain`

构建信息：

- Android Gradle Plugin：`8.13.2`
- `META-INF/version-control-info.textproto` 显示未嵌入 VCS 信息：`NO_SUPPORTED_VCS_FOUND`

## 3. APK 内容结构

主要内容：

```text
classes.dex
assets/model_license.txt
assets/sensitive_ac.bin
assets/dexopt/baseline.prof
assets/dexopt/baseline.profm
lib/arm64-v8a/libai-chat.so
lib/arm64-v8a/libllama.so
lib/arm64-v8a/libggml.so
lib/arm64-v8a/libggml-base.so
lib/arm64-v8a/libggml-cpu-android_armv8.0_1.so
lib/arm64-v8a/libggml-cpu-android_armv8.2_1.so
lib/arm64-v8a/libggml-cpu-android_armv8.2_2.so
lib/arm64-v8a/libggml-cpu-android_armv8.6_1.so
lib/arm64-v8a/libggml-cpu-android_armv9.0_1.so
lib/arm64-v8a/libggml-cpu-android_armv9.2_1.so
lib/arm64-v8a/libggml-cpu-android_armv9.2_2.so
lib/arm64-v8a/libomp.so
lib/*/libdatastore_shared_counter.so
```

观察：

- `assets/model_license.txt` 是模型许可文本。
- `assets/sensitive_ac.bin` 是敏感词 AC 自动机数据，应用启动时 mmap 读取。
- `classes.dex` 约 1.48MB，Java/Kotlin 层被 R8 混淆。
- native 推理库只完整覆盖 `arm64-v8a`。

## 4. Java/Kotlin 层架构

### 4.1 包结构

核心包：

- `com.tencent.hunyuan.angelslim`
  - `App`
  - `MainActivity`
  - `TranslatePopupActivity`
- `com.arm.aichat`
  - `AiChat`
  - `InferenceEngine`
  - `InferenceEngineKt`
  - `UnsupportedArchitectureException`
  - `gguf/*`
- `com.arm.aichat.internal`
  - `InferenceEngineImpl`
- `n2/*`
  - 被混淆的业务辅助类：模型列表、下载、语言列表、翻译 flow、弹窗逻辑等。

### 4.2 Application 初始化

`App.onCreate()` 调用 `n2.c0.f3093a.a(this)`，加载 `assets/sensitive_ac.bin`。

敏感词模块行为：

- 通过 `context.getAssets().openFd("sensitive_ac.bin")` 打开资源。
- 使用 `FileChannel.map()` mmap 为只读 `MappedByteBuffer`。
- 检查 magic 值 `4276996`。
- 后续对输入文本做小写归一化并在 AC 自动机中扫描。

这说明 Demo 内置了轻量文本安全过滤能力，可能在提交翻译前拦截敏感内容。

### 4.3 主界面 MainActivity

`MainActivity` 使用 `R.layout.activity_main`，主要控件包括：

- `tv_status`：模型/翻译状态
- `spinner_model`：模型选择
- `tv_source_label` / `tv_target_label`：源语言、目标语言
- `et_source_input`：输入文本
- `btn_translate`：翻译按钮
- `iv_translate_logo`：翻译按钮图标/动画元素
- `tv_translated_output`：译文输出
- `btn_source_lang` / `btn_target_lang`：语言选择
- `btn_swap`：源/目标语言交换

启动流程：

1. 设置 edge-to-edge / window inset。
2. `setContentView(R.layout.activity_main)`。
3. 绑定控件。
4. 读取 `SharedPreferences("app_prefs")` 中的 `eula_accepted_v2`。
5. 如果未接受 EULA，先弹出协议确认。
6. 接受后进入初始化流程，加载模型列表、状态和推理引擎。

### 4.4 弹窗翻译 TranslatePopupActivity

`TranslatePopupActivity` 使用 `R.layout.popup_translate`，主要用于系统选中文本或分享文本快速翻译。

入口：

- `Intent.ACTION_PROCESS_TEXT`
  - 从 `android.intent.extra.PROCESS_TEXT` 读取文本。
- `Intent.ACTION_SEND`
  - 从分享文本读取输入。

行为：

- 只显示已下载模型。
- 如果默认模型未下载，会提示“模型未下载”，引导打开主应用下载模型。
- 支持选择已下载模型、编辑原文、复制译文、关闭弹窗。
- 若模型已加载或文件存在，则直接触发翻译流程。

## 5. 模型定义与下载策略

### 5.1 模型数据类

`n2.n0` 表示一个翻译模型，字段语义可还原为：

```text
filename: String
 displayName: String
 downloadUrl: String
 fileSizeMb: Int
 zhPromptTemplate: String
 enPromptTemplate: String
 restrictedLanguages: Set<String>
```

默认 prompt 模板：

```text
中文源语言：请将以下内容翻译为{target}：\n\n{text}
非中文源语言：Please translate to {target}:\n\n{text}
```

`n2.n0.b(text, source, target)` 会根据源语言选择中文或英文 prompt 模板，并替换 `{target}` 与 `{text}`。

### 5.2 内置模型列表

APK 内置两个模型定义：

| 显示名 | 本地文件名 | 下载 URL | 标称大小 | 语言限制 |
|---|---|---|---:|---|
| `HyMT-1.25bit` | `HY1.8B-MT-1.25bit.gguf` | `https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-1.25bit.gguf` | 440MB | `gu`, `km`, `hi`, `tl`, `te`, `yue` |
| `HyMT-2bit` | `HY1.8B-MT-2bit.gguf` | `https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF/resolve/master/Hy-MT1.5-1.8B-2bit.gguf` | 573MB | 未看到额外限制 |

重要差异：

- APK 下载 1.25bit 时保存为 `HY1.8B-MT-1.25bit.gguf`。
- 本项目 ModelScope 快照中的文件名是 `Hy-MT1.5-1.8B-1.25bit.gguf` 与 `Hy-MT1.5-1.8B-STQ1_0.gguf`。
- 如果复刻 Demo 的路径策略，需要做文件名映射或软链接/复制。

### 5.3 本地模型目录

模型存在性检查逻辑：

```text
new File(context.getFilesDir(), "models")
new File(files/models, filename).exists()
```

也就是说 Demo 使用应用私有目录：

```text
/data/data/com.tencent.hunyuan.angelslim/files/models/<filename>
```

不是外部存储，也不是 APK assets。

### 5.4 下载流程

下载逻辑位于混淆类 `n2.b0`，jadx 对核心方法反编译不完整，但从周边代码可以确定：

- 使用 `HttpURLConnection`。
- 下载 URL 来自模型定义 `downloadUrl`。
- 下载进度以 `download_progress_format` 更新。
- 下载弹窗可取消。
- 下载完成后更新当前模型 `o0.f3166a`。
- 主界面 spinner 会根据本地是否存在模型文件显示“未下载”状态。

## 6. 推理层设计

### 6.1 Java/Kotlin API

`com.arm.aichat.AiChat` 是入口单例：

- `AiChat.INSTANCE.getInferenceEngine(context)`
- 读取 `context.getApplicationInfo().nativeLibraryDir`
- 创建 `InferenceEngineImpl(nativeLibDir)`
- 缓存为全局单例

`InferenceEngine` 暴露的关键能力：

- `loadModel(modelPath)`
- `setSystemPrompt(systemPrompt)`
- `sendUserPrompt(message, predictLength = 1024)`
- `bench(pp, tg, pl, nr = 1)`
- `cleanUp()`
- `destroy()`
- `getState()`

状态机包含：

- `Uninitialized`
- `Initializing`
- `ModelReady`
- `LoadingModel`
- `UnloadingModel`
- `Benchmarking`
- `ProcessingSystemPrompt`
- `ProcessingUserPrompt`
- `Generating`

`InferenceEngineKt.isModelLoaded()` 判断以下状态为已加载：

- `ModelReady`
- `Benchmarking`
- `ProcessingSystemPrompt`
- `ProcessingUserPrompt`
- `Generating`

`InferenceEngineKt.isUninterruptible()` 判断初始化、加载、卸载、bench、处理 prompt 等状态不可中断。

### 6.2 JNI Native 方法

`InferenceEngineImpl` 中声明的 native 方法：

```text
init(nativeLibDir: String)
load(modelPath: String): Int
prepare(): Int
systemInfo(): String
benchModel(pp: Int, tg: Int, pl: Int, nr: Int): String
processSystemPrompt(systemPrompt: String): Int
processUserPrompt(userPrompt: String, predictLength: Int): Int
generateNextToken(): String?
unload()
shutdown()
```

`libai-chat.so` 导出的 JNI 符号/字符串显示对应函数：

```text
Java_com_arm_aichat_internal_InferenceEngineImpl_init
Java_com_arm_aichat_internal_InferenceEngineImpl_load
Java_com_arm_aichat_internal_InferenceEngineImpl_systemInfo
Java_com_arm_aichat_internal_InferenceEngineImpl_benchModel
Java_com_arm_aichat_internal_InferenceEngineImpl_processSystemPrompt
Java_com_arm_aichat_internal_InferenceEngineImpl_processUserPrompt
Java_com_arm_aichat_internal_InferenceEngineImpl_generateNextToken
Java_com_arm_aichat_internal_InferenceEngineImpl_unload
Java_com_arm_aichat_internal_InferenceEngineImpl_shutdown
```

### 6.3 llama.cpp 调用链

`libai-chat.so` 中可见的 llama/ggml 相关符号包括：

```text
llama_log_set
ggml_backend_load_all_from_path
llama_backend_init
llama_model_default_params
llama_model_load_from_file
llama_batch_init
common_chat_templates_init
common_sampler_init
llama_context_default_params
llama_model_n_ctx_train
llama_init_from_model
llama_print_system_info
llama_n_ctx
llama_decode
llama_free
llama_model_desc
llama_model_size
llama_model_n_params
ggml_backend_reg_count
ggml_backend_reg_get
ggml_backend_reg_name
common_tokenize
llama_memory_seq_rm
llama_memory_seq_add
common_sampler_sample
llama_model_get_vocab
llama_vocab_is_eog
common_token_to_piece
llama_batch_free
llama_model_free
llama_backend_free
```

推理链路可推断为：

1. `init(nativeLibDir)`
   - 设置 llama log。
   - 从 native lib 目录加载 ggml backend。
   - 初始化 llama backend。
2. `load(modelPath)`
   - 设置模型默认参数。
   - 调用 `llama_model_load_from_file`。
   - 初始化 chat template、sampler、context、batch。
3. `processSystemPrompt(systemPrompt)`
   - tokenization。
   - decode system prompt。
   - 操作 llama memory sequence。
4. `processUserPrompt(userPrompt, predictLength)`
   - tokenization。
   - decode user prompt。
   - 设置生成上限。
5. `generateNextToken()`
   - sampler 采样。
   - 判断 EOG。
   - token 转 piece 返回给 Java 层。
6. `unload()` / `shutdown()`
   - 释放 batch、model、backend。

### 6.4 后端与 CPU 优化

APK 打包多个 `ggml-cpu` 变体：

```text
android_armv8.0_1
android_armv8.2_1
android_armv8.2_2
android_armv8.6_1
android_armv9.0_1
android_armv9.2_1
android_armv9.2_2
```

这说明 Demo 依赖 `ggml_backend_load_all_from_path(nativeLibDir)` 在运行时选择合适 CPU backend。未看到 GPU/QNN/Vulkan 相关 so，因此此 APK 主要是 CPU 推理路径。

### 6.5 流式输出实现

本次复查确认：官方 Demo 的流式输出不是 JNI 层主动 callback 到 Kotlin，而是 **Kotlin Flow + native `generateNextToken()` 拉取式接口**。

关键证据：

1. `InferenceEngine` 对外接口中，`sendUserPrompt(message, predictLength)` 返回 `Flow<String>`：

```text
sendUserPrompt(message: String, predictLength: Int = 1024): Flow<String>
```

2. `InferenceEngineImpl.sendUserPrompt()` 创建一个 Flow，内部协程逻辑位于反编译类 `l1.f`。它的生成循环可以还原为：

```kotlin
processUserPrompt(userPrompt, predictLength)
state = Generating

while (!abortRequested) {
    val piece = generateNextToken() ?: break
    if (piece.isNotEmpty()) {
        emit(piece)
    }
}

state = ModelReady
```

3. native 层没有暴露 `translateStream(callback)` 这类 callback API，而是拆成三段：

```text
processSystemPrompt(systemPrompt): Int
processUserPrompt(userPrompt, predictLength): Int
generateNextToken(): String?
```

4. `libai-chat.so` 字符串和 JNI 符号也能看到独立 token 拉取入口：

```text
Java_com_arm_aichat_internal_InferenceEngineImpl_processUserPrompt
Java_com_arm_aichat_internal_InferenceEngineImpl_generateNextToken
common_sampler_sample
llama_vocab_is_eog
common_token_to_piece
```

5. 主界面收集 Flow 后逐 token 更新 `TextView`。反编译类 `n2.s` 调用 `sendUserPrompt()`，再通过 collector `n2.r` 把每个 token 切到主线程；最终 `androidx.lifecycle.n` 中执行：

```text
mainActivity.T.append(token)
tvTranslatedOutput.setText(mainActivity.T.toString())
```

6. 弹窗翻译也采用同类模式：collector 把 token 追加到 `StringBuilder`，再更新结果 `TextView` 并滚动到底部。

因此，官方 Demo 的流式输出边界是：

```text
Kotlin UI
  ↓ collect Flow<String>
InferenceEngine.sendUserPrompt()
  ↓ 每次 emit 一个 piece
native generateNextToken()
  ↓ 每次采样一个 token 并转 piece
llama.cpp sampler / decode
```

这与“一次 native `translate()` 调用内部循环生成，过程中通过 callback/EventChannel 回传 token”的方式不同。callback 方式理论可行，但在 Flutter + MethodChannel/EventChannel 场景下会额外引入事件通道订阅时序、线程切换、结果完成时机和 pending buffer 等问题；官方 Demo 通过拉取式 `generateNextToken()` 避开了这些桥接时序问题。

## 7. 语言与翻译业务逻辑

### 7.1 Prompt 生成

业务层不直接把原文交给模型，而是构造翻译 prompt：

```text
请将以下内容翻译为{target}：

{text}
```

或：

```text
Please translate to {target}:

{text}
```

源语言为中文时使用中文模板，否则使用英文模板。

### 7.2 源语言粗略识别

`MainActivity` / `TranslatePopupActivity` 中存在基于首字符 Unicode 区间的语言识别：

- Hangul：`ko`
- Arabic：`ar`
- Cyrillic：`ru`
- Thai：`th`
- Hebrew：`he`
- Devanagari：`hi`
- CJK：`zh`
- Latin：`en`

这只是启发式，不是完整语言检测。

### 7.3 受限语言

`HyMT-1.25bit` 限制语言集合包含：

```text
gu, km, hi, tl, te, yue
```

UI 层会通过 `TranslationModel.c(lang)` 或 `TranslationModel.a()` 过滤不支持语言。

## 8. UI 与交互

### 8.1 主界面

主界面是工具型翻译 App：

- 顶部状态/模型选择。
- 中间源语言、目标语言、交换按钮。
- 输入框。
- 翻译按钮。
- 输出区域。

资源 ID 表明输出区、按钮背景、模型 badge 都是自定义 drawable：

- `bg_translate_button`
- `bg_translated_output`
- `bg_model_badge`

### 8.2 弹窗翻译

弹窗布局包括：

- 源语言文本
- 目标语言文本
- 模型 badge
- 原文文本
- 翻译结果
- 状态文本
- progress
- 复制、关闭、dismiss 按钮
- 预填充 loading overlay/dots

这套交互可作为本项目 Flutter 版本的参考，但不建议逐像素复制，因为本项目已有 `DESIGN.md` 视觉规范。

## 9. 安全与隐私观察

### 9.1 网络权限

APK 声明 `INTERNET` 与 `ACCESS_NETWORK_STATE`，主要用于下载模型。没有发现模型被内置进 APK。

### 9.2 数据位置

模型下载到应用私有目录 `files/models/`。这降低了外部文件被其他 App 篡改的风险，但也意味着用户卸载 App 时模型会被删除。

### 9.3 敏感词过滤

应用启动时加载 `sensitive_ac.bin`。从实现看，这是本地敏感词扫描，不依赖网络。

### 9.4 公开 Activity

`TranslatePopupActivity` 是 `exported=true`，且接受 `PROCESS_TEXT` / `SEND text/plain`。这符合 Android 分享/选中文本场景，但实现上应确保：

- 对输入长度设上限。
- 对空文本和超长文本快速返回。
- 不在 Activity intent 中信任非文本对象。
- 避免未下载模型时反复拉起重任务。

### 9.5 反编译限制

APK 被 R8 混淆。jadx 反编译完成但报告 2 个错误，且 `n2.b0` 下载核心方法反编译不完整。因此下载实现的细节结论基于周边调用、字段和可见类型推断。

## 10. 对本项目的实现建议

### 10.1 Flutter 与 native bridge 的分层

建议本项目沿用相似边界，但用 Flutter 自身方式封装：

```text
Flutter UI
  ↓ MethodChannel / FFI wrapper
TranslatorEngine
  ↓ JNI/C++ bridge
llama.cpp runtime
  ↓
GGUF model file
```

Dart 层建议抽象：

```dart
abstract interface class TranslatorEngine {
  Stream<TranslatorEvent> translate(TranslationRequest request);
  Future<void> loadModel(String path);
  Future<void> unloadModel();
  Future<void> cancel();
}
```

### 10.2 模型路径策略

Demo 的 Android 私有目录策略适合移动端：

```text
<app files dir>/models/<model filename>
```

本项目本地开发目录与移动端目录应分开：

- 桌面开发缓存：`models/AngelSlim/...`
- Android 运行时：`context.filesDir/models/...`
- iOS 运行时：`Application Support/models/...`

### 10.3 文件名映射

本项目当前推荐：

```text
Hy-MT1.5-1.8B-STQ1_0.gguf
```

APK Demo 内置下载名：

```text
HY1.8B-MT-1.25bit.gguf
```

建议本项目不要直接采用 Demo 的内部文件名，而是保留上游文件名，并在配置里记录模型 ID、显示名、文件名、下载 URL、hash 和兼容 loader。

### 10.4 推理状态机

Demo 的状态机值得复用：

```text
Uninitialized
Initializing
LoadingModel
ModelReady
ProcessingSystemPrompt
ProcessingUserPrompt
Generating
UnloadingModel
Benchmarking
```

本项目还应增加：

- `Cancelling`
- `Failed(error)`
- `MissingModel`
- `UnsupportedModelFormat`
- `UnsupportedDevice`

### 10.5 安全执行

结合本仓库安全规则，移动端 native 推理应具备：

- 非交互式推理接口。
- 最大输入长度。
- 最大输出 token。
- 可取消生成。
- 后台线程/isolates，不阻塞 UI。
- 错误可恢复：模型加载失败后能回到未加载状态。
- 日志不输出完整用户文本。

### 10.6 Android ABI 策略

Demo 只对 `arm64-v8a` 携带完整推理库。Flutter MVP 也建议先只支持：

```text
android-arm64
```

原因：

- 目标 Android 手机基本覆盖 arm64。
- GGUF 推理库体积大，多 ABI 会显著增加包体。
- 当前 `STQ1_0` loader 依赖固定 llama.cpp PR，先降低构建矩阵复杂度。

### 10.7 流式输出实现建议

结合官方 Demo，建议本项目把流式输出收敛为 **pull-based token API**，而不是继续依赖 native 生成线程主动 callback：

```text
Flutter TranslatorController
  ↓ await for
Platform bridge translateStream()
  ↓ 循环调用 nextToken
native processUserPrompt()
native generateNextToken()
```

推荐接口拆分：

```text
loadModel(path, nCtx, nThreads)
setSystemPrompt(systemPrompt)
beginTranslation(userPrompt, maxTokens)
nextToken(): String?
cancelGeneration()
unloadModel()
```

Android 可直接映射官方 Demo 的结构：

- Kotlin `Flow<String>` / coroutine 在 engine 单线程 dispatcher 上运行。
- `beginTranslation()` 先完成 user prompt prefill。
- `while` 循环调用 JNI `nativeGenerateNextToken()`。
- 每个非空 piece 通过 Flutter `EventChannel` 或 MethodChannel stream 包装给 Dart。
- 生成结束或 EOG 时关闭 stream。

macOS/iOS 也应采用同样的 shared native 状态机：

- ObjC++/Swift 只负责启动生成和拉取 token。
- C++ `translator_engine` 持有上下文、sampler、batch、剩余 token 数和取消标记。
- `generateNextToken()` 每次只做一步 decode/sample/token-to-piece。

这种方案的优点：

- 与官方 Demo 已验证路径一致。
- 每个 token 是一次明确的跨层返回，便于日志和调试。
- 可清晰区分 prefill 阶段和 decode 阶段，UI 可在 prefill 时显示“翻译中”，decode 时逐 token 更新。
- 避免 native 线程在 MethodChannel 调用未完成时向 EventChannel 抢发事件导致丢 token 或看起来不流式。

对本项目当前实现的修正方向：

- 保留 Dart `TranslatorService.translateStream()` 抽象。
- 将 native callback 式 `translate(text, onToken)` 改为 `beginTranslation()` + `generateNextToken()`。
- Android/macOS 两端都用同一套 C++ step API，平台桥只做薄封装。
- EventChannel 仍可保留，但事件来源应是平台层主动循环拉取 token 后发送，而不是 C++ 内部 callback 直接推送。

## 11. 可复现分析命令

```bash
file models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT-demo.apk
unzip -l models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT-demo.apk
jadx -d /private/tmp/hy_mt_demo_jadx models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT-demo.apk
unzip -q models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT-demo.apk 'lib/*' 'assets/*' 'META-INF/*' -d /private/tmp/hy_mt_demo_apk
strings /private/tmp/hy_mt_demo_apk/lib/arm64-v8a/libai-chat.so | rg 'llama|ggml|InferenceEngine|model|prompt|token' -i
```

## 12. 结论

`Hy-MT-demo.apk` 的核心价值不在 UI，而在它展示了一个可行的移动端离线翻译闭环：

1. 应用私有目录管理 GGUF 模型。
2. UI 层维护模型下载/选择/翻译状态。
3. Kotlin coroutine + Flow 处理异步生成。
4. JNI 层封装 `llama.cpp`。
5. native 层按设备 CPU 能力加载 ggml backend。
6. 支持主应用翻译和系统选中文本弹窗翻译两种入口。

本项目可以借鉴其架构边界和状态机，但应继续以 `DESIGN.md`、Flutter 架构文档和 `llama.cpp` PR #22836 的 `STQ1_0` 兼容性为准，不应直接复刻 APK 的文件命名、UI 风格或混淆后的业务结构。

## 13. 专项说明：模型与 `llama.cpp` 是如何结合进 APK 的

这一部分是本次逆向里最值得关注的点。结论先说：**他们不是把模型和 `llama.cpp` 一起“编译进” APK，而是把 `llama.cpp` 运行时编译成 Android `.so`，再在运行时加载单独下载到本地的 GGUF 模型文件。**

### 13.1 不是“模型编译进 so”，而是“so + 外部模型文件”

APK 内容已经说明：

- APK 里有 `libai-chat.so`、`libllama.so`、`libggml.so`、`libggml-base.so`、多个 `libggml-cpu-android_armv*.so`
- APK 里**没有** 440MB 级 GGUF 模型文件
- 模型是在业务层通过 URL 下载到 `context.getFilesDir()/models/`

也就是说它的组成是：

```text
APK
├─ Java/Kotlin UI + business logic
├─ JNI bridge: libai-chat.so
├─ llama runtime: libllama.so
├─ ggml core: libggml.so + libggml-base.so
├─ CPU backends: libggml-cpu-android_armv*.so
└─ assets: license / sensitive filter / profile

运行时
└─ /data/data/<package>/files/models/*.gguf
```

这和“把模型固化到安装包里”完全不同。

### 13.2 so 依赖链已经暴露出分层方式

通过 `objdump -p` 可看到依赖关系：

`libai-chat.so` 依赖：

- `libllama.so`
- `libggml.so`
- `libggml-base.so`
- `libandroid.so`
- `liblog.so`

`libllama.so` 依赖：

- `libggml.so`
- `libggml-base.so`

`libggml-cpu-android_armv8.2_1.so` 依赖：

- `libggml-base.so`
- `libomp.so`

说明它们的层次基本是：

```text
Kotlin / Java
  ↓ JNI
libai-chat.so
  ↓
libllama.so
  ↓
libggml.so + libggml-base.so
  ↓ runtime backend loading
libggml-cpu-android_armv*.so
```

其中：

- `libai-chat.so` 是他们自己的桥接层，负责把 Android 业务接口转成 `llama.cpp` 调用。
- `libllama.so` 是 `llama.cpp` 主库。
- `libggml.so` / `libggml-base.so` 是张量和 backend 基础设施。
- `libggml-cpu-android_armv*.so` 是面向不同 ARM ISA 的 CPU backend 插件。

### 13.3 关键结合点：`nativeLibraryDir` + backend 动态装载

`AiChat.getInferenceEngine(context)` 会取：

```text
context.getApplicationInfo().nativeLibraryDir
```

然后把这个路径传入 `InferenceEngineImpl(nativeLibDir)`。

JNI 层里又有：

- `init(nativeLibDir)`
- `ggml_backend_load_all_from_path`

这说明它的设计不是把所有 CPU backend 静态链接成一个 monster `.so`，而是：

1. Android 安装 APK 后，把各个 `.so` 解到应用 native lib 目录。
2. `libai-chat.so` 初始化时拿到 `nativeLibraryDir`。
3. 调用 `ggml_backend_load_all_from_path(nativeLibDir)`。
4. `ggml` 在这个目录里发现并加载多个 `libggml-cpu-android_armv*.so`。
5. 运行时根据设备 CPU 能力选最合适的 backend。

这也是为什么 APK 里能同时存在：

- `libggml-cpu-android_armv8.0_1.so`
- `libggml-cpu-android_armv8.2_1.so`
- `libggml-cpu-android_armv8.2_2.so`
- `libggml-cpu-android_armv8.6_1.so`
- `libggml-cpu-android_armv9.0_1.so`
- `libggml-cpu-android_armv9.2_1.so`
- `libggml-cpu-android_armv9.2_2.so`

这是一种**“runtime backend discovery”** 的打包方式，不是单一硬编码后端。

### 13.4 模型加载的真正入口是文件路径，不是 asset 句柄

JNI 符号里能看到：

- `Java_com_arm_aichat_internal_InferenceEngineImpl_load`
- `llama_model_load_from_file`

同时 Java 层 `loadModel(modelPath)` 的参数就是一个字符串路径。

这表明模型结合方式非常直接：

```text
业务层得到本地模型文件路径
  ↓
JNI load(modelPath)
  ↓
llama_model_load_from_file(modelPath, params)
```

因此“模型和 `llama.cpp` 的结合点”本质上是**文件路径协议**，不是编译期嵌入。

### 13.5 他们的 Android 打包方式大概率是什么

虽然 APK 里没有 Gradle/CMake 工程文件，不能 100% 还原，但从产物形态看，大概率是：

1. 用 Android NDK + CMake 构建 `llama.cpp` 动态库：
   - `libllama.so`
   - `libggml.so`
   - `libggml-base.so`
   - `libggml-cpu-android_armv*.so`
2. 再构建自定义 JNI 桥接库 `libai-chat.so`，链接到 `libllama.so` / `libggml*.so`
3. Gradle 打包这些 `.so` 到 `lib/arm64-v8a/`
4. Java/Kotlin 层通过 `System.loadLibrary` 或依赖加载顺序自动拉起 `libai-chat.so`
5. `libai-chat.so` 在 `init()` 中调用 `ggml_backend_load_all_from_path(nativeLibraryDir)`，继续发现同目录下的 backend 插件

从 `libai-chat.so` 中存在：

- `Java_com_arm_aichat_internal_InferenceEngineImpl_*`
- `llama_*`
- `ggml_backend_load_all_from_path`
- `__android_log_print`

可以非常稳地支持这个推断。

### 13.6 他们为什么要这样拆，而不是只打一个库

这种拆分方式有几个明显优点：

- **易适配不同 ARM ISA**：把优化实现拆成多个 backend 插件。
- **减少桥接层复杂度**：业务 JNI 只关心调用 `llama.cpp` API，不关心每种 CPU 优化细节。
- **方便跟随 `llama.cpp` upstream 演进**：`llama` / `ggml` / backend 可以相对独立更新。
- **模型与 runtime 解耦**：同一套 APK runtime 可加载多个 GGUF 文件，不用为每个模型重新发 APK。

### 13.7 对本项目最直接的启发

如果本项目后续做 Flutter Android 集成，最推荐复用的不是它的 Java 业务代码，而是它的**分层打包思路**：

```text
flutter_app/
  android/
    app/
    src/main/jniLibs/arm64-v8a/
      libtranslator_engine.so
      libllama.so
      libggml.so
      libggml-base.so
      libggml-cpu-android_armv*.so
      libomp.so
```

其中：

- `libtranslator_engine.so` 相当于这里的 `libai-chat.so`
- 由它接收 Flutter MethodChannel/FFI 请求
- 初始化时传入 `nativeLibraryDir`
- 调用 `ggml_backend_load_all_from_path()`
- 模型文件保持在应用私有目录，而不是打包进 APK

### 13.8 对 `STQ1_0` 兼容路线的影响

这份 APK 默认走的是下载 `Hy-MT1.5-1.8B-1.25bit.gguf` 的路线；而本仓库当前更重视 `STQ1_0` 与 `llama.cpp` `PR #22836` 的兼容。

因此本项目实现时要注意：

- 可以借鉴它的 Android 打包方式；
- **不能**直接照搬它的模型文件名和模型清单；
- `libtranslator_engine.so` 应绑定我们固定的 `third_party/llama.cpp/` 版本；
- 运行时模型清单需要明确区分：
  - `displayName`
  - `downloadUrl`
  - `filename`
  - `quantization`
  - `required_llama_commit`
  - `loader_compatibility`

简化成一句话：

> 他们是把 `llama.cpp` 编成 Android 动态库打进 APK，再在运行时从应用私有目录加载 GGUF；模型本身不是编译进 APK，也不是编译进 `so`。

## 14. macOS / iOS 平台迁移注意事项

Android APK 的 `.so + nativeLibraryDir + ggml_backend_load_all_from_path()` 方案只能作为架构参考，不能原样搬到 Apple 平台。macOS 和 iOS 的 native 产物、动态库加载规则、模型文件位置、加速后端都不同。

### 14.1 三个平台的产物对照

| 平台 | native 产物 | 推荐加载方式 | 模型文件位置 | 主要后端 |
|---|---|---|---|---|
| Android | `.so` | JNI / Dart FFI / MethodChannel | app private `files/models/` | CPU backend `.so`，可选 Vulkan/QNN 另议 |
| macOS | `.dylib` / `.framework` / 静态库 | Dart FFI / Flutter macOS plugin / Swift bridge | `Application Support/<app>/models/` 或开发期 `models/` | CPU / Metal |
| iOS | `.a` / `.xcframework` / framework | Flutter iOS plugin / Swift/ObjC bridge / Dart FFI | `Application Support/models/`，必要时 `Documents` | CPU / Metal，受 App Store 和 sandbox 限制 |

共同点是：**模型仍然应该作为运行时文件加载，不建议编译进 native 库。**

### 14.2 macOS 的推荐形态

macOS 没有 Android APK 的 `lib/arm64-v8a/` 目录，也没有 `nativeLibraryDir`。如果做 Flutter macOS 版本，推荐两种路线：

路线 A：动态库方式

```text
flutter_app/macos/
  Runner/
  Frameworks/
    libtranslator_engine.dylib
    libllama.dylib
    libggml.dylib
    libggml-base.dylib
    libggml-metal.dylib 或内置 Metal 支持
```

路线 B：静态链接方式

```text
Flutter macOS plugin
  ↓ links
translator_engine + llama.cpp + ggml
  ↓ produces
Runner.app/Contents/MacOS/Runner
```

macOS 上如果启用 Metal，需要额外考虑：

- `ggml-metal` / Metal backend 是否被编译进产物或作为动态库提供。
- `.metallib` 或 Metal shader 是否随 bundle 打包。
- universal binary：Apple Silicon `arm64` 与 Intel `x86_64` 是否都要支持。

本项目 MVP 如果只面向当前 Apple Silicon 开发机，可以先只做：

```text
macos-arm64 + CPU/Metal 单一路线
```

但报告层面要明确：macOS 的产物不是 `.so`，而是 `.dylib`、`.framework`、`.xcframework` 或静态链接进 app。

### 14.3 iOS 的推荐形态

iOS 更严格，不能像 Android 那样随意在运行时从目录 `dlopen` 一堆插件库。通常更推荐：

```text
llama.cpp + ggml + translator bridge
  ↓ Xcode / CMake / CocoaPods 构建
TranslatorEngine.xcframework
  ↓ Flutter iOS plugin 链接
Runner.app
```

iOS 注意点：

- 不推荐依赖运行时发现 backend 插件；优先在构建期确定 CPU/Metal backend。
- 动态库必须被正确签名并嵌入 app bundle；静态库/`xcframework` 更容易控风险。
- iOS app sandbox 下模型文件应放在 app container，例如：

```text
Application Support/models/<filename>.gguf
```

- 如果模型由用户下载，不能放在只读 app bundle。
- 如果模型随 app 分发，包体会暴涨，且 App Store 分发、首包下载、审核体验都要重新评估。
- 后台长时间推理、电量、热管理、内存峰值都比 macOS 更敏感。

### 14.4 Apple 平台上的模型加载仍然是“文件路径协议”

无论 macOS 还是 iOS，建议继续保持和 Android 一样的抽象：

```text
Flutter / Swift / ObjC
  ↓
TranslatorEngine.loadModel(modelPath)
  ↓
llama_model_load_from_file(modelPath, params)
```

也就是说平台差异主要在 native runtime 怎么编译、链接和打包；模型结合点仍然是 GGUF 文件路径。

### 14.5 不能照搬 Android backend 插件机制

Android Demo 的关键点是：

```text
ggml_backend_load_all_from_path(nativeLibraryDir)
```

这在 Android 上很自然，因为 APK 解包后有 ABI 目录和多个 `.so`。但 Apple 平台要谨慎：

- macOS 可以做动态库发现，但需要处理 rpath、签名、notarization、bundle 路径。
- iOS 不建议做运行时 backend 插件发现，优先静态链接或固定 framework。
- Metal 后端不是简单的 CPU `.so` 插件平替，还涉及 shader、设备能力和内存策略。

因此 Apple 平台建议改成：

```text
Android: runtime discover backends from nativeLibraryDir
macOS: app bundle 内固定 dylib/framework，必要时显式初始化 Metal
iOS: xcframework/静态链接固定后端，避免动态插件化
```

### 14.6 对 Flutter 工程的建议目录

Android：

```text
flutter_app/android/app/src/main/jniLibs/arm64-v8a/
  libtranslator_engine.so
  libllama.so
  libggml.so
  libggml-base.so
  libggml-cpu-android_armv*.so
  libomp.so
```

macOS：

```text
flutter_app/macos/Runner/Frameworks/
  TranslatorEngine.framework 或 libtranslator_engine.dylib
  llama/ggml 相关 dylib 或合并后的 framework
```

iOS：

```text
flutter_app/ios/Frameworks/
  TranslatorEngine.xcframework
```

或通过 Flutter plugin / CocoaPods：

```text
flutter_app/packages/translator_engine/
  ios/translator_engine.podspec
  macos/translator_engine.podspec
  native/
    CMakeLists.txt
    translator_engine.cpp
```

### 14.7 本项目的跨平台落地建议

建议把“翻译引擎”设计为平台无关接口，平台实现分别处理 native 产物：

```text
Dart TranslatorEngine interface
  ├─ AndroidTranslatorEngine: JNI/FFI + .so
  ├─ MacosTranslatorEngine: FFI/Swift + .dylib/.framework
  └─ IosTranslatorEngine: Swift/ObjC + .xcframework/static lib
```

模型清单保持平台无关：

```text
model_id
display_name
filename
download_url
sha256
quantization
required_llama_commit
supported_platforms
preferred_backend
```

特别是 `STQ1_0` 路线，必须保证 Android、macOS、iOS 都来自同一个固定 `llama.cpp` PR #22836 对应 commit，避免出现“Android 能加载、Apple 平台不能加载”的版本漂移。

一句话总结：

> Android Demo 证明了“runtime native 库 + 外部 GGUF 文件”的路线可行；macOS/iOS 也应保持外部 GGUF 文件加载，但 native runtime 要按 Apple 的 `.dylib` / `.framework` / `.xcframework` 规则重新打包，不能照搬 APK 的 `.so` 插件目录机制。
