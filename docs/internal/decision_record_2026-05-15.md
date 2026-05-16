# 2026-05-15 决策记录

## 目标平台

- 当前主目标是 **Apple Silicon / ARM 移动端**。
- 当前目标**不是**在 Windows 上做高性能本地推理。

## 本轮已验证

- `llama.cpp` `PR #22836` 支持 `STQ1_0` 的基本加载链路。
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 在当前 PR 分支上可完成最小输出验证。
- Windows 上最小样例 `translate to chinese: hello` 可输出 `你好`。

## 本轮遇到的问题

- Windows 上直接运行交互式 `llama-cli` 风险高，容易长时间停留在会话模式。
- 当前 Windows 构建未启用 GPU 后端，不适合作为性能参考。
- `STQ1_0` 这条路线与 ARM / Apple Silicon 的匹配度高于 Windows x86。
- `uv` 默认缓存目录曾出现权限问题。

## 已做调整

- 模型目录调整为按来源分层：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/`
- `llama.cpp` PR 拉取方式调整为更轻量的获取方式。
- 新增安全 smoke test：`scripts/safe_llama_smoketest.py`
- 新增 Windows 包装器：`scripts/safe_llama_smoketest.ps1`
- 新增 Windows 安全规则文档：`docs/llama_windows_safety.md`

## 当前决策

- Windows 只承担：
  - 文档整理
  - 模型下载与目录规范验证
  - `llama.cpp` PR 最小兼容验证
  - 安全 smoke test
- Apple Silicon / ARM 环境承担：
  - 更真实的运行路径验证
  - 后续性能与产品方向判断

## 暂不优先处理

- Windows GPU build
- Windows 性能优化
- Windows 长时间推理压测

这些工作当前都不属于主目标。
