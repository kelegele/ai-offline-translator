# Windows 上运行 llama.cpp 的安全规则

## 为什么需要这份规则

在 Windows 上直接运行交互式 `llama-cli`，很容易同时踩中以下风险：

- 进入 CPU fallback，长时间吃满 CPU
- 占用大量 RAM 和 pagefile
- 交互式会话不退出，持续挂在终端里
- 输出过多时拖慢终端或调用方

这与在 Apple Silicon / macOS 上的体验可能明显不同，不能简单类比。

## 默认规则

- 默认使用：`uv run scripts/safe_llama_smoketest.py`
- 禁止把交互式 `llama-cli` 当作 smoke test
- 优先 GPU offload
- GPU 未确认可用时，禁止高负载推理
- CPU fallback 只能用于受限、短时、可自动退出的验证

## 受限 smoke test 要求

- `stdin` 关闭
- 必须设置超时
- 必须设置输出上限
- 必须限制线程数
- 必须限制 `n_ctx`
- 必须限制 `n_predict`
- 失败时必须 kill 子进程

## 当前脚本

- `scripts/safe_llama_smoketest.py`
- `scripts/safe_llama_smoketest.ps1`

## 推荐命令

```powershell
.\scripts\safe_llama_smoketest.ps1
```

如需受限 CPU fallback：

```powershell
.\scripts\safe_llama_smoketest.ps1 -AllowCpu
```

## 不推荐的做法

- 直接运行交互式 `llama-cli`
- 在未知 GPU 状态下跑长 prompt 或大 `n_ctx`
- 不加超时地运行模型
- 把性能压测当作加载验证
