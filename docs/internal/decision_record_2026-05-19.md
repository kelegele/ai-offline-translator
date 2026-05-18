# 2026-05-19 决策记录

## HarmonoyOS NEXT 方案调整：Flutter on OHOS 替代 ArkTS/ArkUI 原生栈

### 背景

先前方案（2026-05-15）假设 HarmonyOS NEXT 没有可用 Flutter SDK，结论是按 ArkTS/ArkUI + NAPI 原生栈路线规划。

### 本轮发现

**openharmony-tpc/flutter_flutter**（https://gitcode.com/openharmony-tpc/flutter_flutter）：
- OpenHarmony 社区 Flutter SDK fork，基于 Flutter 3.27.4
- 最新版本 `3.27.4-ohos-1.0.5`（2026-03-30 发布），同时维护 3.7.12、3.22、3.32 Beta
- 30 位贡献者，976 stars，BSD-3-Clause 协议
- 支持 impeller-vulkan 渲染
- 同一份 SDK 可编译 Android/iOS 包
- 多款 Flutter 应用已基于此上架 AppGallery

**华为官方适配指南**（https://developer.huawei.com/consumer/cn/blog/topic/03199049270088065）：
- `flutter create --platforms ohos --t app ./` 一行命令添加 ohos 底座
- 支持 Flutter App 和 Flutter Module（har）两种模式
- 两种工作流：一套代码一套流水线，或一套代码两套流水线
- 环境：DevEco Studio + OHOS SDK + OHOS Flutter SDK

### 版本约束

- 当前 flutter_app 使用 Dart SDK `^3.9.2`（对应 Flutter 3.33+ 或 git main）
- OHOS Flutter SDK 3.27.4 对应 Dart 3.6.x
- OHOS Flutter SDK 3.32 Beta 对应 Dart 3.8.x
- 采用 Flutter on OHOS 需降级到 3.27.4 或等 3.32 正式版

### 决策

**首选 Flutter on OHOS 路径**，复用现有 flutter_app UI 和业务逻辑。备选 ArkTS/ArkUI 原生栈。

理由：
- 已有完整 `flutter_app/`，功能对齐 PRD，经过多轮迭代和真机验证
- 桥接模式（platform channel → C++）可在 OHOS Flutter 上直接沿用
- 翻译工具型 App 不依赖复杂第三方插件，插件兼容风险低
- 开发工时约 2-3 周 vs ArkTS 重写 6-10 周
- 后续三端（macOS / Android / OHOS）共享一个 Flutter 代码库

### 已做调整

- 更新 `docs/internal/harmonyos_next_plan.md`：新增 2026-05-18 方案补充章节、两条路径对比表、Flutter 降级评估专项、调整 Phase 0-5 为 Flutter 优先
- 更新 `README.md`：平台对照表和技术路线描述
- 更新 `docs/internal/flutter_mobile_architecture.md`：HarmonyOS NEXT 关系章节
- 更新 `docs/internal/PRD.md`：HarmonyOS 规划和推理路线

### 新增风险

- Flutter OHOS SDK 版本滞后（Dart 3.9.2 → 3.6.x 降级）
- Flutter OHOS 插件兼容性（当前 App 依赖少，风险可控）
- llama.cpp OHOS 编译和 STQ1_0 仍然是最大技术风险（与路径无关）

### 下一步

进入 Phase 0 前先做 Flutter 降级评估：检查 `lib/` 是否使用 Dart 3.7+ 特性、pubspec 依赖兼容性。

如果降级验证失败且修复成本过高，重新评估是否切换到 ArkTS/ArkUI 原生栈。
如果 OHOS Flutter SDK 3.32 正式版包含 Dart 3.8.x，优先等待而非大幅降级。