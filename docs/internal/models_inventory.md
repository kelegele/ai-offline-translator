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

## Hy-MT2 GGUF 记录

截至 2026-05-24，本机已拉取 Hunyuan Hy-MT2 的两个 llama.cpp GGUF 量化仓库：

```bash
git clone https://huggingface.co/tencent/Hy-MT2-1.8B-2Bit-GGUF models/AngelSlim/Hy-MT2-1.8B-2bit-GGUF
git clone https://huggingface.co/tencent/Hy-MT2-1.8B-1.25Bit-GGUF models/AngelSlim/Hy-MT2-1.8B-1.25bit-GGUF
```

标准项目路径：

- `models/AngelSlim/Hy-MT2-1.8B-2bit-GGUF/Hy-MT2-1.8B-2Bit.gguf`
- `models/AngelSlim/Hy-MT2-1.8B-1.25bit-GGUF/Hy-MT2-1.8B-1.25Bit.gguf`

本机文件检查：

- `Hy-MT2-1.8B-2Bit.gguf`：573 MB，GGUF magic header 正常
- `Hy-MT2-1.8B-1.25Bit.gguf`：440 MB，GGUF magic header 正常

当前结论：

- `Hy-MT2-1.8B-1.25Bit.gguf` 可以直接进入现有 Application 的“导入模型 -> 加载模型 -> 翻译”技术路径。已用 App 共用 `TranslatorEngine` 验证加载成功，`hello` 最小翻译输出 `你好`。
- `Hy-MT2-1.8B-2Bit.gguf` 不能用当前固定的 `llama.cpp` submodule 直接加载。当前 submodule 报 tensor offset 不匹配：`tensor 'blk.0.attn_k_norm.weight' has offset 203248672, expected 203572256`。
- `Hy-MT2-1.8B-2Bit.gguf` 可以通过 `llama.cpp` PR #19357 兼容路径加载。临时构建 `921df044b291d5bd95106d0ed42b91b87e1712c2` 后，App 共用 `TranslatorEngine` 验证加载成功，`hello` 最小翻译输出 `你好`。
- PR #19357 不能直接替换当前 submodule：它可加载 2bit，但加载 `Hy-MT2-1.8B-1.25Bit.gguf` 失败，报 `tensor 'blk.0.attn_k.weight' has invalid ggml type 42. should be in [0, 41)`。若要一个 App runtime 同时支持 1.25bit 和 2bit，需要合并 PR #22836 的 STQ1_0 支持与 PR #19357 的 q2_0c 支持。
- 默认下载仍硬编码 `Hy-MT1.5-1.8B-STQ1_0.gguf`，若要把 Hy-MT2 1.25bit 设为默认模型，需要同步更新 macOS / Android 默认下载地址、文件名、README / PRD / setup 脚本。
- 多语言能力已记录到 PRD，但现有 UI 语言选择仍只覆盖英语 / 中文。要完整使用 Hy-MT2 的 39 种语言，需要扩展语言选择器、语言代码映射和 RTL / 竖排排版处理。

当前 submodule 失败验证：

```bash
/tmp/translator_engine_smoketest models/AngelSlim/Hy-MT2-1.8B-2bit-GGUF/Hy-MT2-1.8B-2Bit.gguf hello
```

失败结果：

- `load failed`
- `tensor 'blk.0.attn_k_norm.weight' has offset 203248672, expected 203572256`

PR #19357 兼容验证：

```bash
rm -rf /tmp/llama-pr19357
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /tmp/llama-pr19357
git -C /tmp/llama-pr19357 fetch --depth 1 origin pull/19357/head
git -C /tmp/llama-pr19357 checkout FETCH_HEAD
cmake -S /tmp/llama-pr19357 -B /tmp/llama-pr19357/build \
  -DGGML_METAL=OFF \
  -DGGML_ACCELERATE=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TOOLS=ON \
  -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/llama-pr19357/build --target llama-completion -j 6
```

App 共用 `TranslatorEngine` 验证：

```bash
clang++ -std=c++17 \
  scripts/translator_engine_smoketest.cpp \
  flutter_app/native/translator_engine/translator_engine.cpp \
  -Iflutter_app/native/translator_engine \
  -I/tmp/llama-pr19357/include \
  -I/tmp/llama-pr19357/common \
  -I/tmp/llama-pr19357/vendor \
  -I/tmp/llama-pr19357/ggml/include \
  /tmp/llama-pr19357/build/common/libcommon.a \
  /tmp/llama-pr19357/build/vendor/cpp-httplib/libcpp-httplib.a \
  -L/tmp/llama-pr19357/build/bin \
  -lllama -lggml -lggml-cpu -lggml-base -lggml-blas \
  -framework Accelerate -lc++ \
  -Wl,-rpath,/tmp/llama-pr19357/build/bin \
  -o /tmp/translator_engine_smoketest_pr19357

/tmp/translator_engine_smoketest_pr19357 models/AngelSlim/Hy-MT2-1.8B-2bit-GGUF/Hy-MT2-1.8B-2Bit.gguf hello
```

验证结果：

- `Hy-MT2-1.8B-1.25Bit.gguf`：`load ok`，`translation: 你好`
- `Hy-MT2-1.8B-2Bit.gguf` + PR #19357：`load ok`，`translation: 你好`
- `Hy-MT2-1.8B-1.25Bit.gguf` + PR #19357：`load failed`，`invalid ggml type 42`

## 作者本机历史路径

以下路径只用于追溯验证记录，不是项目标准路径：

- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-1___25bit__GUFF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- `/Users/fh/LLMs/AngelSlim/Hy-MT1___5-1___8B-2bit__GUFF/Hy-MT1.5-1.8B-2bit.gguf`
