# 模型清单与当前结论

## 项目模型目录

本仓库统一使用：

- `models/`

模型下载命令：

```powershell
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF
```

也可以运行一键初始化脚本：

```powershell
.\scripts\setup.ps1
```

模型大文件不提交到 Git。

## ModelScope 来源

- 模型仓库：`AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`
- 本地下载目录：`models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/`
- 模型仓库：`AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF`
- 本地下载目录：`models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF/`

下载后重点关注：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-1.25bit.gguf`

截至 2026-05-15，本机已用以下命令补全该 ModelScope 仓库快照：

```powershell
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF
```

当前本地快照文件：

- `README.md`
- `License.txt`
- `Hy-MT1.5-1.8B-STQ1_0.gguf`
- `Hy-MT1.5-1.8B-1.25bit.gguf`
- `Hy-MT-demo.apk`
- `app_demo.gif`
- `demo2.gif`
- `fp16vs1.25bit.gif`
- `Sherry.png`
- `flores_model_size.png`
- `model_scores.png`

## 推荐的 MVP 模型

推荐优先使用：

- `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`

原因：

- 已在作者本机实际验证可加载
- 已在作者本机实际验证可翻译
- 与 `llama.cpp` PR #22836 的目标格式 `STQ1_0` 一致

## 2bit GGUF 记录

标准项目路径：

- `models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF/Hy-MT1.5-1.8B-2bit.gguf`

截至 2026-05-19，本机已用以下命令补全该 ModelScope 仓库快照：

```powershell
modelscope download --model AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF --local_dir models/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF --max-workers 4
```

当前本地快照文件：

- `README.md`
- `License.txt`
- `Hy-MT1.5-1.8B-2bit.gguf`
- `Hy-MT-demo.apk`
- `app_demo.gif`
- `demo2.gif`
- `sme2_2bit.gif`
- `flores_model_size.png`
- `model_scores.png`

GGUF 校验：

- 文件大小：573 MB
- SHA256：`2603ca8063c77328b544f8f6414b398d95893deafb60a9c1f11c2d2af4a20bfe`
- 与作者本机历史路径 `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf` 的 SHA256 一致

当前结论：

- 与当前公开 `llama.cpp` 候选 loader / writer 组合不兼容
- 已验证失败的候选：
  - 当前 submodule：`7ef6976b218cfce6158165f4c63a094acb70e707`
  - PR #22836 auto-merge：`3aee90b50ff11f6c1917a8af55cbf4a8a37c394d`
  - `origin/master` 对照：`9a532ae4bab1b164052ce60a738f78538b421c66`
- 三个候选均加载时报同一个错误：`tensor 'blk.0.attn_k_norm.weight' has offset 203248672, expected 203129888`
- 暂不作为 MVP 模型来源

官方 `Hy-MT-demo.apk` 能支持 `HyMT-2bit`，但现有静态分析只能确认 APK 自带 `libai-chat.so`、`libllama.so`、`libggml*.so` 和 ARM64 CPU backend 插件，不能从 stripped `.so` 中确认精确 `llama.cpp` commit。当前验证结论是：不要假设“更新到 `llama.cpp` 最新主线”或“使用 PR #22836 merge ref”即可支持这份 2bit GGUF；需要继续追溯官方 demo runtime 的额外兼容改动或内部 loader 版本。

注意：这个结论不等于所有 2bit GGUF 都不可用，只表示当前官方样本和上述公开 loader 组合不可用。

## 作者本机历史路径

以下路径只用于追溯验证记录，不是项目标准路径：

- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf`
