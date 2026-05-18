# HarmonyOS NEXT 原生端方案

## 2026-05-18 方案补充：Flutter on OHOS 路径

先前方案假设 HarmonyOS NEXT 没有可用 Flutter SDK，结论是走 ArkTS/ArkUI 原生栈。调查后发现该假设不成立。

### 发现

- **openharmony-tpc/flutter_flutter**（[GitCode](https://gitcode.com/openharmony-tpc/flutter_flutter)）：OpenHarmony 社区 Flutter SDK fork，基于 Flutter 3.27.4，最新 `3.27.4-ohos-1.0.5`（2026-03-30 发布）。30 位贡献者，976 stars，BSD-3-Clause 协议。同时维护 3.7.12、3.22 和 3.32 Beta 版本。支持 impeller-vulkan 渲染。
- **华为官方适配指南**（[开发者博客](https://developer.huawei.com/consumer/cn/blog/topic/03199049270088065)）：`flutter create --platforms ohos --t app ./` 一行命令即可为现有 Flutter 工程添加 ohos 底座。同一份 OHOS Flutter SDK 还能编译 Android/iOS 包。多款 Flutter 应用已基于此上架 AppGallery。

### 当前 flutter_app 版本约束

```text
flutter_app/pubspec.yaml:  environment: sdk: ^3.9.2
OHOS Flutter SDK:        Flutter 3.27.4 -> Dart 3.6.x
                         Flutter 3.32 Beta -> Dart 3.8.x
```

当前 flutter_app 运行在 Dart 3.9.2+（对应 Flutter 3.33 或 git main），远高于 OHOS Flutter SDK 对应的 Dart 版本。采用 Flutter on OHOS 路径需要将 flutter_app **降级到 Flutter 3.27.4 / Dart 3.6.x**，或等 OHOS Flutter SDK 追上 3.33+。

### 两条路径对比

| | Flutter on OHOS | ArkTS/ArkUI 原生栈 |
| --- | --- | --- |
| UI 代码复用 | 复用全部 Flutter UI（Dart） | 全部用 ArkTS/ArkUI 重写 |
| 桥接层 | 沿用现有 platform channel 模式，dart:ffi / MethodChannel | NAPI（全新桥接代码） |
| 业务逻辑复用 | ~95% Dart 代码复用 | 仅复用 C++ engine |
| 开发工时估算 | Phase 0-5 约 2-3 周（大部分是环境 + native spike） | Phase 0-5 约 6-10 周（重写全部 UI） |
| SDK 依赖 | 社区 fork（openharmony-tpc），有华为官方背书 | 无第三方 UI 框架依赖 |
| 版本风险 | 需降级 Flutter 3.27.4（或等 3.32+ 正式版） | 无 Flutter 版本依赖 |
| 后续维护 | 三端（macOS / Android / OHOS）共享一个 Flutter 代码库 | OHOS 端独立 ArkTS 代码库，需与 macOS/Android 手动对齐 |

### 推荐路径：Flutter on OHOS

对本案而言 Flutter on OHOS 是明显更优的选择：

- 已有完整 `flutter_app/`，功能对齐 PRD，UI 经过多轮迭代和真机验证
- translator_engine 的桥接模式（platform channel -> C++）在 OHOS Flutter 上可直接沿用
- 翻译工具型 App 不依赖复杂第三方插件，插件兼容风险低
- 省去全套 ArkTS UI 重写，产出时间大幅缩短

降级 Flutter 3.27.4 需要确认：
1. 当前代码是否使用了 Dart 3.7+ 才有的特性
2. flutter_app 依赖的第三方 package 是否兼容 Flutter 3.27.4
3. 是否值得等 OHOS Flutter SDK 追上 Flutter 3.32+（Dart 3.8.x）

以下方案内容保留两条路径的完整信息。如无特别说明，后续实施默认走 **Flutter on OHOS 路径**，但保留 ArkTS/ArkUI 原生栈作为 fallback。

---

## 目标

规划一个面向 HarmonyOS NEXT 的 App 端。不依赖 Android APK 兼容层。

核心目标：

- 复用现有 C++ 推理核心 `translator_engine.cpp`
- 优先通过 Flutter on OHOS 复用现有 flutter_app UI 和业务逻辑
- 继续只面向 ARM64 设备
- 功能对齐 `docs/internal/PRD.md`

## 结论（更新于 2026-05-18）

**首选：Flutter on OHOS 路径**

```text
Flutter (Dart) UI — 复用 flutter_app/lib/
  -> platform channel / dart:ffi
  -> translator_bridge_ohos (ArkTS + C++)
  -> shared native translator_engine
  -> llama.cpp / ggml (OHOS Native SDK 编译)
  -> Hy-MT1.5 STQ1_0 GGUF
```

**备选：ArkTS/ArkUI 原生栈**

```text
ArkTS / ArkUI
  -> NAPI bridge
  -> shared native translator_engine
  -> llama.cpp / ggml
  -> Hy-MT1.5 STQ1_0 GGUF
```

两条路径共享推理核心、模型策略、prompt / chat template 路线和产品流程。均不可直接复用 Android `.so`、Android JNI 或 Kotlin 下载器。
区别在于 UI 层是复用 Flutter 还是 ArkTS/ArkUI 重写。

## 芯片与 ABI 判断

主流鸿蒙手机，包括麒麟芯片设备，硬件层面可以按 ARM64 / AArch64 方向规划。

命名差异：

| 环境 | 常见名称 | 说明 |
| --- | --- | --- |
| Android | `arm64-v8a` | Android NDK ABI 名称 |
| HarmonyOS NEXT / OHOS Native | `aarch64-linux-ohos` | OHOS Native toolchain 目标 |
| 硬件 | ARM64 / AArch64 | 麒麟等手机 SoC 的 CPU 架构方向 |

约束：

- 继续禁止 x86 / x86_64 路线
- llama.cpp 继续优先验证 ARM64 NEON 路径
- Android 构建产物不能直接给 HarmonyOS NEXT 使用
- HarmonyOS NEXT 必须用 OHOS Native SDK 重新编译 native `.so`

## 可复用模块

### 1. C++ 推理核心

优先复用：

```text
flutter_app/native/translator_engine/translator_engine.hpp
flutter_app/native/translator_engine/translator_engine.cpp
```

复用要求：

- 不引入 Flutter / Android / macOS 平台依赖
- 继续使用 llama.cpp common 层处理 chat template、tokenize、sampler、token-to-piece
- 保持 `beginTranslation + generateNextToken` 的流式模型
- 推理线程不能阻塞 UI 主线程（Flutter 路径下是 Dart isolate + platform channel；ArkTS 路径下是 NAPI 后台线程）

### 2. llama.cpp 依赖路线

继续固定到支持 `STQ1_0` 的 PR #22836 兼容路径。

需要重新验证：

- OHOS Native SDK 下能否编译 llama.cpp / ggml
- C++17、`std::thread`、`std::atomic`、文件 IO 是否满足现有引擎需求
- ARM64 NEON 路径是否可用
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 是否可加载并完成最小翻译

### 3. 产品流程

可直接照搬：

- 模型导入或下载到 App 私有目录
- 不支持手填模型路径
- UI 只展示模型名称，不展示完整路径
- 启动时扫描私有目录，有模型则自动加载
- 原文 200 有效字符限制
- 流式译文输出
- 译文复制反馈
- "结果由 AI 生成，仅供参考"
- Flutter on OHOS 路径还额外复用：全部 Flutter UI（lib/）、provider 状态管理、平台 channel 桥接模式、打字机流式渲染逻辑

## Flutter on OHOS 路径：工程结构

建议在现有 `flutter_app/` 内添加 `ohos/` 平台目录（与 `android/`、`macos/` 并列）：

```text
flutter_app/
├─ ohos/                          # flutter create --platforms ohos --t app
│  ├─ entry/src/main/ets/         # ArkTS 平台代码（仅 platform channel 桥接）
│  ├─ entry/src/main/cpp/         # CMake + translator_bridge + llama.cpp 链接
├─ lib/                           # 共享 Dart 业务代码（不变）
├─ native/translator_engine/      # 共享 C++ 推理核心（不变，被 ohos CMake 引用）
```

说明：

- `ohos/` 目录由 `flutter create --platforms ohos --t app ./` 自动生成
- `entry/src/main/ets/` 只放必要的 platform channel handler（ArkTS）——这是所有 Flutter on OHOS 应用的标准模式
- `entry/src/main/cpp/` 放 CMakeLists.txt，引用 `flutter_app/native/translator_engine/` 和 llama.cpp，产出 `.so`
- Flutter 页面代码（`lib/`）无需任何修改即可在 OHOS 上运行

## ArkTS/ArkUI 原生栈路径：工程结构（备选）

（仅在 Flutter on OHOS 路径不可行时启用）

```text
ai-offline-translator/
├─ harmony_app/
│  ├─ entry/
│  │  ├─ src/main/ets/
│  │  └─ src/main/cpp/
│  ├─ oh-package.json5
│  └─ build-profile.json5
└─ scripts/
   └─ build_harmony_native.sh
```

说明：

- `harmony_app/` 是 HarmonyOS NEXT 原生工程
- `entry/src/main/ets/` 放 ArkTS / ArkUI 页面
- `entry/src/main/cpp/` 放 NAPI bridge 与 CMake 配置
- `flutter_app/native/translator_engine/` 作为 shared native source，被 HarmonyOS 工程引用
- `scripts/build_harmony_native.sh` 仅在工具链稳定后再固化

---

# 以下为通用部分（两条路径共享）

## NAPI / Platform Channel 接口设计

Flutter on OHOS 路径使用 platform channel（MethodChannel），ArkTS/ArkUI 路径使用 NAPI。

业务接口保持一致：

```text
loadModel(path: string): Promise<ModelStatus>
unloadModel(): Promise<void>
beginTranslation(text: string, sourceLanguage: string, targetLanguage: string): Promise<void>
generateNextToken(): Promise<TokenResult>
cancel(): Promise<void>
getModelStatus(): Promise<ModelStatus>
```

`TokenResult` 建议结构：

```text
{
  text: string,
  done: boolean,
  error?: string
}
```

设计原因：

- 和 Android / macOS 当前流式方案一致
- 渲染层可控制打字机渲染节奏
- Native 层只负责真实 token 生成
- 取消、错误和完成状态边界清晰

## UI 对齐范围

首版 HarmonyOS NEXT UI 必须功能对齐 PRD，不要求像素级复制 Flutter UI。

（Flutter on OHOS 路径下 UI 自动对齐，因为复用同一份 `lib/` 代码）

页面结构：

- 顶部标题：`AI离线翻译`
- `了解更多` 入口
- 模型状态胶囊
- 模型看板：导入、下载、加载、卸载、进度
- 语言选择：中文 / 英语，对调按钮
- 原文输入框：清空、N/200 计数、200 有效字符限制
- 翻译按钮：翻译中状态、禁用状态
- 译文卡片：流式输出、复制反馈
- 底部提示：`结果由 AI 生成，仅供参考`

## 模型管理

HarmonyOS NEXT 端继续使用 App 私有目录，不依赖开发机路径。

要求：

- 导入：系统 Picker 选择 `.gguf`
- 下载：默认 ModelScope 模型
- 保存：App 私有 `models/` 目录
- 校验：扩展名、GGUF magic header、最小文件大小
- 启动：扫描私有目录并自动加载

默认模型：

```text
Hy-MT1.5-1.8B-STQ1_0.gguf
```

默认下载源：

```text
https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf
```

## Flutter 降级评估（Flutter on OHOS 路径专项）

在 Phase 1 之前必须先完成：

- 检查 `flutter_app/lib/` 是否使用 Dart 3.7+ 特性（records、patterns、sealed class 增强等）
- 检查 `flutter_app/pubspec.yaml` 各依赖的最低 Dart SDK 约束
- 将 `sdk: ^3.9.2` 改为 `sdk: '>=3.6.0 <4.0.0'`（适配 Flutter 3.27.4 / Dart 3.6.x）
- `flutter analyze` + `flutter test` 验证无 breaking change
- 评估是否值得等 OHOS Flutter SDK 3.32 正式版（Dart 3.8.x），缩小降级幅度

如果降级验证失败：
- 若失败项 <= 3 且修复成本低 -> 修复后继续 Flutter 路径
- 若失败项 > 3 或涉及深度依赖变更 -> 再次评估 Flutter vs ArkTS/ArkUI 原生栈

## 分阶段待办

### Phase 0：文档与环境确认

- 确认 DevEco Studio 版本
- 确认 HarmonyOS NEXT SDK / Native SDK 版本
- 确认真机设备和系统版本
- 确认项目能否使用 NAPI + CMake
- **Flutter on OHOS 路径新增**：下载 OHOS Flutter SDK，配置 `flutter doctor -v` 通过
- **Flutter on OHOS 路径新增**：在现有 `flutter_app/` 执行 `flutter create --platforms ohos --t app ./`，验证 ohos/ 目录生成
- **Flutter on OHOS 路径新增**：尝试 `flutter build hap`（空壳），验证工具链完整
- **Flutter on OHOS 路径新增**：完成 Flutter 降级评估（见上方专项章节）

输出：

- `docs/internal/harmonyos_next_plan.md`
- 设备与 SDK 记录
- Flutter 降级评估结论

### Phase 1：最小 Flutter on OHOS 工程

- 在 `flutter_app/ohos/` 中添加最小 platform channel：Dart 侧调用 `echo()` / `add()`
- ohos/ets/ 侧实现 platform channel handler（ArkTS）
- 验证 Flutter -> ArkTS -> C++ 调用链完整

验收：

- 真机启动成功
- `flutter build hap` 成功
- Flutter UI 正常渲染
- Dart 调 ArkTS platform channel 成功

（如走 ArkTS/ArkUI 路径，Phase 1 改为最小 NAPI 工程，验证 ArkTS -> NAPI -> C++ 调用链）

### Phase 2：llama.cpp 编译 Spike

- 使用 OHOS Native SDK 编译 llama.cpp / ggml
- 只保留 ARM64
- 关闭 server、tools、tests、curl 等非必要模块
- 产出可链接 native 库（Flutter 路径下通过 ohos/ CMake 链接；ArkTS 路径下通过 harmony_app CMake 链接）

验收：

- CMake 构建通过
- `translator_engine.cpp` 能链接
- `flutter build hap`（Flutter 路径）或 hvigor 构建（ArkTS 路径）包含该 `.so`

### Phase 3：最小翻译 Smoke Test

- 固定本地模型路径
- 调用 `loadModel`
- 调用 `beginTranslation + generateNextToken`
- 输出一次中文 / 英文最小翻译

验收：

- `Hy-MT1.5-1.8B-STQ1_0.gguf` 加载成功
- 能输出非乱码译文
- 可取消推理

### Phase 4：模型管理闭环

- 系统 Picker 导入 GGUF
- ModelScope 下载
- App 私有目录落盘
- 启动自动扫描并加载
- 下载进度、取消、失败状态

验收：

- 不依赖开发机路径
- 导入 / 下载 / 自动加载都可用

### Phase 5：UI 功能对齐

- **Flutter 路径**：Flutter UI 已对齐，仅需验证 OHOS 平台上的行为一致性（文件选择器、网络权限、本地路径权限等）
- **ArkTS 路径**：完成 PRD 核心交互，流式输出由 ArkTS 渲染层控制 30-50ms/token
- 复制、清空、语言对调、字符限制全部补齐

验收：

- 功能对齐 Android / macOS v0.1.0
- 真机连续翻译稳定

## 风险清单

1. **llama.cpp OHOS 编译风险**
   - 最大风险点。必须先做编译 Spike，不要先投入 UI。

2. **STQ1_0 兼容风险**
   - 即使 llama.cpp 能编译，也必须验证 PR #22836 的 STQ1_0 路径在 OHOS 上可用。

3. **NAPI / Platform Channel 线程模型风险**
   - 推理必须跑在后台线程，UI 更新必须回到 UI 安全路径。

4. **文件权限与 Picker 风险**
   - HarmonyOS NEXT 的沙盒、Picker、导入文件复制流程和 Android 不同。

5. **下载链路风险**
   - ModelScope 下载需要验证网络权限、断点/取消、临时文件清理。

6. **Flutter OHOS SDK 版本滞后风险**（新增）
   - 当前 flutter_app 使用 Dart 3.9.2+，需降级到 3.6.x 才能用 OHOS Flutter SDK 3.27.4。降级可能导致 breaking change。可等待 OHOS Flutter SDK 3.32 正式版缩小差距。

7. **Flutter OHOS 插件兼容风险**（新增）
   - `flutter_app` 依赖的第三方 package 需要有 ohos 平台适配（或使用 pure Dart 实现绕过）。当前翻译 App 插件依赖较少，风险可控。

8. **性能与内存风险**
   - 麒麟芯片是 ARM64，但不同型号 CPU、内存和调度差异明显，不能用 Android 或 macOS 表现推断。

## 暂不做

- 不做 ArkTS/ArkUI 全量 UI 重写（除非 Flutter 路径被验证不可行）
- 不做 Android APK 兼容层适配
- 不做 x86 / x86_64
- 不接入 NPU
- 不做多模型市场
- 不做 AppGallery 上架流程，直到 native smoke test 通过

## 进入开发的前置条件

**Flutter on OHOS 路径**进入产品化开发前，必须满足：

1. Flutter 降级评估通过（或确认等待 3.32 正式版）
2. 有可用 HarmonyOS NEXT 真机
3. DevEco Studio + OHOS Flutter SDK + Native SDK 环境可用
4. `flutter create --platforms ohos` 生成 ohos/ 成功，`flutter build hap` 空壳通过
5. llama.cpp + `translator_engine.cpp` OHOS 编译通过
6. `Hy-MT1.5-1.8B-STQ1_0.gguf` 真机最小翻译通过

如果第 5 或第 6 条失败，应暂停 UI 投入，先解决 native 编译与推理问题。

如果 Flutter 降级评估失败且修复成本过高，应重新评估是否切换到 ArkTS/ArkUI 原生栈路径。
如果 OHOS Flutter SDK 3.32 正式版包含 Dart 3.8.x（接近当前 3.9.x），优先等待而非大幅降级。