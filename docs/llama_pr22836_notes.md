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

## 本地验证

### 成功样本

模型：
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`

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
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf`

结果：
- 加载失败

错误特征：
- GGUF tensor offset 不匹配
- 说明文件布局或 writer/loader 版本不兼容

结论：
- 不能把这个 2bit GGUF 当成 STQ1_0 支持验证样本
