# 模型清单与当前结论

## 模型根目录

- `/Users/fh/LLMs/AngelSlim`

## 目录 1: 2bit GGUF

路径：
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF`

关键文件：
- `Hy-MT1.5-1.8B-2bit.gguf`

当前结论：
- 与本地 `pr-22836` 上构建的 llama.cpp 不兼容
- 加载时报 tensor offset mismatch
- 暂不作为 MVP 模型来源

## 目录 2: 1.25bit / STQ1_0 GGUF

路径：
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF`

关键文件：
- `Hy-MT1.5-1.8B-1.25bit.gguf`
- `Hy-MT1.5-1.8B-STQ1_0.gguf`
- `Hy-MT-demo.apk`
- `README.md`

当前结论：
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 已成功跑通
- 优先作为离线翻译 App MVP 的模型文件

## 推荐的 MVP 模型

推荐优先使用：
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`

原因：
- 已实际验证可加载
- 已实际验证可翻译
- 与 `PR #22836` 的目标格式完全一致
