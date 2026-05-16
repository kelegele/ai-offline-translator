# 2026-05-15 验证状态与问题记录

## 结论摘要

- 当前仓库的主要目标**不是在 Windows 上做高性能运行**。
- 当前阶段，Windows 只用于：
  - 文档整理
  - 模型下载与目录规范验证
  - `llama.cpp` PR #22836 的最小加载验证
- 真正更贴近目标的平台是：
  - Apple Silicon / macOS
  - ARM 移动端（Android / iOS）

## 本次已确认事项

### 模型与代码

- 模型来源：`AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`
- MVP 模型文件：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `llama.cpp` 工作树：`third_party/llama.cpp/`
- 当前 PR 分支：`pr-22836`

### Windows 上的最小验证

已验证：

- `PR #22836` 这份代码能在 Windows 上构建出 `llama-cli`
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 能被当前构建正确加载
- 最小 prompt `translate to chinese: hello` 能输出 `你好`

这说明：

- `STQ1_0` 支持链路基本成立
- 模型文件本身不是坏的
- 当前重点问题不是“能不能加载”，而是“在哪个平台上以什么方式安全运行”

## 遇到的问题

### 1. Windows 上直接跑交互式 `llama-cli` 风险很高

现象：

- 直接进入 conversation / interactive 模式
- 生成完成后不自动退出
- 终端会持续停留在 `>` 提示符
- 如果调用环境继续读取输出，容易出现大量输出和长时间占用

影响：

- 容易误以为“程序卡死”
- 会持续占用 CPU / RAM / pagefile
- 在 Windows 上更容易拖慢甚至拖挂主机

### 2. 当前 Windows 构建没有 GPU 支持

已观察到日志：

- `no usable GPU found`
- `llama.cpp was compiled without GPU support`

这说明：

- 当前构建是 CPU-only build
- 即使传 `-ngl`，也不会真正进行 GPU offload
- 当前 Windows 路线不适合做性能验证

### 3. `STQ1_0` 的优化方向更偏 ARM / Apple Silicon

当前理解：

- `PR #22836` 的重点是支持 `STQ1_0`
- 同时包含 ARM NEON 优化方向
- 因此它与 Apple Silicon / ARM 移动端的匹配度更高

这也解释了：

- 为什么在 MacBook Air 上体验更自然
- 为什么在 Windows x86 上更像“能跑的兼容验证”，而不是理想运行平台

### 4. `uv` 默认缓存目录曾出现权限问题

已遇到错误：

- `C:\Users\Felic\AppData\Local\uv\cache` 拒绝访问

当前处理方式：

- 使用仓库内缓存目录作为临时规避方案

## 已做出的调整

### 1. 模型目录结构调整

从平铺目录调整为按模型仓库分目录：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/`

原因：

- 便于未来支持多个模型
- 避免 `README.md`、`License.txt` 等文件相互覆盖
- 更接近真实的模型来源结构

### 2. `llama.cpp` 拉取方式调整

从完整 clone 调整为更轻量的 PR 抓取方式，降低 Windows / 网络环境下失败概率。

### 3. 新增安全 smoke test 脚本

脚本：

- `scripts/safe_llama_smoketest.py`
- `scripts/safe_llama_smoketest.ps1`

当前策略：

- 强制非交互
- 强制单轮退出
- 限制 `n_ctx`
- 限制 `n_predict`
- 限制线程数
- 设置超时
- 设置输出上限
- 失败时 kill 子进程
- Python 执行必须走 `uv`

### 4. 新增 Windows 安全文档

- `docs/llama_windows_safety.md`

目的：

- 明确记录 Windows 上为什么容易出问题
- 明确哪些跑法禁止继续使用

## 当前判断

- Windows 上的价值：**验证兼容性与最小加载**
- Mac / Apple Silicon / 移动 ARM 的价值：**验证真实目标运行路径**

因此后续不建议：

- 把“Windows 上跑得快”作为当前阶段目标
- 把 Windows 上 CPU-only 结果当作产品性能判断依据

## 后续建议

优先级更高的方向：

1. 继续完善移动端架构与原生推理封装
2. 在 Apple Silicon / ARM 环境继续验证 `STQ1_0`
3. 把 Windows 角色限定为：
   - 文档
   - 目录规范
   - 安全 smoke test
   - 基础兼容验证

优先级较低的方向：

1. Windows GPU build
2. Windows 性能优化
3. Windows 长时间推理压测

这些工作目前都不属于主目标。
