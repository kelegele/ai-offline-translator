# llama.cpp PR #22836 认知整理

## PR 基本信息

- PR: `#22836`
- 标题: `ggml-cpu : add STQ1_0 ternary quantization with ARM NEON vec_dot kernel`
- 分支来源: `sjl623/llama.cpp:STQ_0`
- 本地审查分支: `pr-22836`

## 核心能力

PR #22836 的核心是为 llama.cpp / ggml 增加一种新量化格式：`STQ1_0`。

主要改动：
- 新增 `GGML_TYPE_STQ1_0`
- 新增 `LLAMA_FTYPE_MOSTLY_STQ1_0`
- 新增 `block_stq1_0`
- 新增 quantize / dequantize 逻辑
- 新增 generic CPU fallback dot kernel
- 新增 ARM NEON 优化 kernel
- 新增 `llama-quantize` 对 `STQ1_0` 的支持

## STQ1_0 是什么

`STQ1_0` 是面向 Sherry 的 **1.25-bit 结构化三值量化**。

约束：
- 每 4 个权重一组
- 固定 1 个为 0
- 其余 3 个只能是 `-d` 或 `+d`

模式数：
- 4 个零位置选择
- 3 个非零位各自正负
- 总计 32 种模式
- 理论上约 1.25 bit / weight

在 ggml 实现中，加上 scale 后实际约为 1.3125 bpw。

## x86 与 ARM 的理解

- `x86` / `ARM` 是 CPU 架构，不是操作系统
- x86: Intel / AMD 常见 PC
- ARM: 手机、Apple Silicon Mac 等

对这个 PR：
- x86 可以跑，但主要走 generic fallback
- ARM 有专门优化 kernel
- 因此手机和 Apple Silicon 是重点目标

当前项目判断：
- Windows / x86 的意义主要是兼容验证和最小加载验证
- Apple Silicon / ARM 更接近这个 PR 的真实目标运行路径

## 本地验证

### 成功样本

模型：
- 项目标准路径：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- 作者本机历史路径：`/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`

结果：
- 已成功加载
- 已完成翻译推理

案例：
- 输入: `translate to chinese: hello`
- 输出: `你好。`

案例：
- 输入: `translate to chinese: The weather is nice today, and I want to go for a walk after dinner.`
- 输出: `今天的天气不错，我准备在晚餐后出去散步。`

### 失败样本

模型：
- 项目标准路径：`models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF/Hy-MT1.5-1.8B-2bit.gguf`
- 作者本机历史路径：`/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf`
- SHA256：`2603ca8063c77328b544f8f6414b398d95893deafb60a9c1f11c2d2af4a20bfe`

结果：
- 加载失败

错误特征：
- `tensor 'blk.0.attn_k_norm.weight' has offset 203248672, expected 203129888`
- 说明文件布局或 writer/loader 版本不兼容

结论：
- 不能把这个 2bit GGUF 当成 STQ1_0 支持验证样本
- 当前问题更像这份 GGUF 与当前 loader / writer 组合不兼容，不等于所有 2bit GGUF 都不兼容
- PR #22836 的边界是 `STQ1_0` / 1.25bit 支持，不应被表述为 Hy-MT 2bit 支持
- Hy-MT2 2bit 使用 `q2_0c`，官方页面指向 `llama.cpp` PR #19357。它不是 PR #22836 的 `STQ1_0` 路径。
- 当前结论：1.25bit / `STQ1_0` 需要 PR #22836；2bit / `q2_0c` 需要 PR #19357。若要一个 App runtime 同时支持两者，需要合并两个 PR 的 ggml / llama.cpp 改动。

截至 2026-05-19 的追加验证：

- 当前 submodule `7ef6976b218cfce6158165f4c63a094acb70e707`：失败，同一 tensor offset mismatch
- PR #22836 auto-merge `3aee90b50ff11f6c1917a8af55cbf4a8a37c394d`：失败，同一 tensor offset mismatch
- `origin/master` 对照 `9a532ae4bab1b164052ce60a738f78538b421c66`：失败，同一 tensor offset mismatch

官方 `Hy-MT-demo.apk` 中 `HyMT-2bit` 能加载的事实，说明 APK 自带 runtime 与上述公开候选不同。静态分析显示它基于 `llama.cpp` Android example 风格的 `libai-chat.so` + `libllama.so` + `libggml*.so` 方案，但 stripped `.so` 没有保留可确认的 `llama.cpp` commit。后续若要支持 2bit，应优先追溯 demo runtime 的额外 loader 兼容改动，而不是继续盲目切换公开 master / PR merge。
