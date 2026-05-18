# HarmonyOS NEXT 原生端方案

## 目标

规划一个面向 HarmonyOS NEXT 的原生 App 端。该端不依赖 Android APK 兼容层，也不假设 Flutter 官方完整支持 HarmonyOS NEXT。

核心目标：

- 复用现有 C++ 推理核心 `translator_engine.cpp`
- 使用 HarmonyOS 原生 UI 与原生桥接
- 继续只面向 ARM64 设备
- 功能对齐 `docs/internal/PRD.md`

## 结论

HarmonyOS NEXT 端应按“新平台端”处理：

```text
ArkTS / ArkUI
  -> NAPI bridge
  -> shared native translator_engine
  -> llama.cpp / ggml
  -> Hy-MT1.5 STQ1_0 GGUF
```

可复用的部分是推理核心、模型策略、prompt / chat template 路线和产品流程。不可直接复用 Android `.so`、Android JNI、Kotlin 下载器或 Flutter 页面。

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
- 推理线程不能阻塞 ArkTS UI 主线程

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
- “结果由 AI 生成，仅供参考”

## 需要新建的 HarmonyOS 模块

建议新增目录：

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

## NAPI 接口设计

HarmonyOS 端不要沿用 Android JNI 方法名，使用平台原生 NAPI wrapper，但业务能力保持一致。

建议暴露：

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
- ArkTS 层可控制打字机渲染节奏
- Native 层只负责真实 token 生成
- 取消、错误和完成状态边界清晰

## UI 对齐范围

首版 HarmonyOS NEXT UI 必须功能对齐 PRD，不要求像素级复制 Flutter UI。

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

## 分阶段待办

### Phase 0：文档与环境确认

- 确认 DevEco Studio 版本
- 确认 HarmonyOS NEXT SDK / Native SDK 版本
- 确认真机设备和系统版本
- 确认项目能否使用 NAPI + CMake

输出：

- `docs/internal/harmonyos_next_plan.md`
- 设备与 SDK 记录

### Phase 1：最小 NAPI 工程

- 新建 `harmony_app/`
- ArkTS 页面调用 C++ `echo()` / `add()`
- 验证 `.so` 能打包、加载、调用

验收：

- 真机启动成功
- ArkTS 调 native 方法成功

### Phase 2：llama.cpp 编译 Spike

- 使用 OHOS Native SDK 编译 llama.cpp / ggml
- 只保留 ARM64
- 关闭 server、tools、tests、curl 等非必要模块
- 产出可链接 native 库

验收：

- CMake 构建通过
- `translator_engine.cpp` 能链接

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

- 完成 PRD 中的核心交互
- 流式输出由 ArkTS 渲染层控制 30-50ms/token
- 复制、清空、语言对调、字符限制全部补齐

验收：

- 功能对齐 Android / macOS v0.1.0
- 真机连续翻译稳定

## 风险清单

1. **llama.cpp OHOS 编译风险**
   - 最大风险点。必须先做编译 Spike，不要先投入 UI。

2. **STQ1_0 兼容风险**
   - 即使 llama.cpp 能编译，也必须验证 PR #22836 的 STQ1_0 路径在 OHOS 上可用。

3. **NAPI 线程模型风险**
   - 推理必须跑在后台线程，ArkTS UI 更新必须回到 UI 安全路径。

4. **文件权限与 Picker 风险**
   - HarmonyOS NEXT 的沙盒、Picker、导入文件复制流程和 Android 不同。

5. **下载链路风险**
   - ModelScope 下载需要验证网络权限、断点/取消、临时文件清理。

6. **性能与内存风险**
   - 麒麟芯片是 ARM64，但不同型号 CPU、内存和调度差异明显，不能用 Android 或 macOS 表现推断。

## 暂不做

- 不做 Android APK 兼容层适配
- 不做 x86 / x86_64
- 不接入 NPU
- 不做多模型市场
- 不做 AppGallery 上架流程，直到 native smoke test 通过

## 进入开发的前置条件

进入 HarmonyOS NEXT 产品化开发前，必须满足：

1. 有可用 HarmonyOS NEXT 真机
2. DevEco Studio + Native SDK 环境可用
3. NAPI 最小工程跑通
4. llama.cpp + `translator_engine.cpp` 编译通过
5. `Hy-MT1.5-1.8B-STQ1_0.gguf` 真机最小翻译通过

如果第 4 或第 5 条失败，应暂停 UI 投入，先解决 native 编译与推理问题。
