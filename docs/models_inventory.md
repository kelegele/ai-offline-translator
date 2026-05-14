# 模型清单与当前结论

## 项目模型目录

本仓库统一使用：

- `models/`

模型下载命令：

```powershell
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF
```

也可以运行一键初始化脚本：

```powershell
.\scripts\setup.ps1
```

模型大文件不提交到 Git。

## ModelScope 来源

- 模型仓库：`AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`
- 本地下载目录：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/`

下载后重点关注：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-1.25bit.gguf`

## 推荐的 MVP 模型

推荐优先使用：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`

原因：

- 已在作者本机实际验证可加载
- 已在作者本机实际验证可翻译
- 与 `llama.cpp` PR #22836 的目标格式 `STQ1_0` 一致

## 2bit GGUF 记录

作者本机曾验证：

- `Hy-MT1.5-1.8B-2bit.gguf`

当前结论：

- 与作者本机 `pr-22836` loader / writer 组合不兼容
- 加载时报 tensor offset mismatch
- 暂不作为 MVP 模型来源

注意：这个结论不等于所有 2bit GGUF 都不可用，只表示当前样本和当前 loader 组合不可用。

## 作者本机历史路径

以下路径只用于追溯验证记录，不是项目标准路径：

- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf`
