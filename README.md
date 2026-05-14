# ai-offline-translator

离线翻译 App 项目工作目录。

当前已确认：
- `llama.cpp` 的 `PR #22836` 支持 `STQ1_0`
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 已在本机成功加载并完成翻译推理
- `Hy-MT1.5-1.8B-2bit.gguf` 当前与本地 `pr-22836` loader 不兼容

建议优先路线：
- 使用 `Hy-MT1.5-1.8B-STQ1_0.gguf`
- 推理层基于包含 `PR #22836` 的 `llama.cpp`
- App 方案优先采用“Flutter UI + 原生推理层”

详细资料见 `docs/`。
