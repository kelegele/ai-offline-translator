# 离线翻译 App PRD

## 产品目标

构建一个移动端优先的离线翻译 App。用户可以在无网络推理环境下完成短文本翻译，模型文件通过导入或下载进入 App 私有目录，运行时不依赖开发机路径。

## 当前版本范围

### v0.1.0

首个双平台（macOS + Android）功能完整可用版本：

- 流式翻译，打字机逐字渲染效果（40ms/token）
- 模型下载（ModelScope）支持进度回调、取消、验证
- 模型导入（系统文件选择器）到 App 私有目录
- 启动时自动检测并加载已有模型
- 翻译中显示 spinner +「翻译中」状态
- 译文复制按钮（翻译完成后可点）
- 原文输入限制 200 有效字符，N/200 计数显示
- 清空原文按钮（输入框右上角 X icon）
- 语言选择（英语/中文），支持对调
- 「了解更多」入口直达关于页面
- 关于页面：微信复制、GitHub 链接点击打开
- App 桌面图标（macOS + Android）
- macOS DMG 安装引导
- Android 沉浸式 edge-to-edge 布局
- 发布流程：GitHub Release 自动上传 APK + DMG

### 规划：HarmonyOS NEXT 原生端

HarmonyOS NEXT 按新平台端规划，不依赖 Android APK 兼容层。

- UI 使用 ArkTS / ArkUI 原生实现
- Native bridge 使用 NAPI 调用 C++ `.so`
- 复用 shared native `translator_engine.cpp`
- llama.cpp / ggml 使用 OHOS Native SDK 重新编译
- 仅支持 ARM64 / AArch64，不支持 x86 / x86_64
- 功能目标对齐 macOS / Android v0.1.0
- 进入产品化前必须先完成真机 native smoke test

### v0.0.2

- 用户只能通过"导入模型"或"下载模型"获得模型
- 不支持手动输入模型路径
- 界面只显示模型名称，不展示完整路径
- 模型名称展示区域不可编辑

## 核心用户流程

### 1. 导入模型

1. 用户点击"导入模型"
2. 平台弹出系统文件选择器
3. 用户选择 `.gguf` 模型文件
4. App 将模型复制到平台私有模型目录
5. App 校验文件类型和 GGUF magic header
6. 成功后模型面板显示模型文件名
7. 用户点击"加载模型"

平台目录：
- Android：`files/models/`
- macOS：`Application Support/ai_offline_translator/models/`

### 2. 下载模型

1. 用户点击"下载模型"
2. App 从 ModelScope 下载 `Hy-MT1.5-1.8B-STQ1_0.gguf`
3. 下载过程展示进度
4. 允许取消（删除临时文件）
5. 下载完成后校验 GGUF magic header
6. 校验通过后保存到 App 私有目录
7. 模型面板显示模型文件名
8. 用户点击"加载模型"

### 3. 加载与翻译

1. 启动时自动检测 App 私有目录已有模型，存在则自动加载
2. 若无模型，用户需手动导入或下载后加载
3. 用户在 App 中点击"加载模型"
4. 加载成功后输入原文
5. 原文限制 200 有效字符（不计空格、符号）
6. N/200 显示在输入框右下角
7. 点击"翻译"
8. 流式输出译文（打字机效果，40ms/token）
9. 翻译完成后可复制译文
10. 可清空原文重新输入

## 跨端一致性要求

- macOS、Android 产品行为必须一致
- HarmonyOS NEXT **首选 Flutter on OHOS 路径**（复用 flutter_app），产品行为必须对齐 macOS / Android。备选 ArkTS/ArkUI 原生栈。
- 各端都不能提供手填路径输入框
- 各端都不能在普通界面展示完整本地路径
- 各端都必须把模型落到 App 私有目录
- 各端都必须支持导入模型
- 各端都应支持下载默认模型、下载进度、取消下载
- 各端启动时自动扫描私有目录，已有模型则自动加载
- 各端流式翻译效果和 UI 反馈一致

## 支持的语言

Hy-MT2 支持以下语言方向。产品语言选择器应以该清单为准，并保留语言代码用于 prompt、模型调用和排版方向判断。

| Languages | Abbr. | Chinese Names |
| --- | --- | --- |
| Chinese | zh | 中文 |
| English | en | 英语 |
| French | fr | 法语 |
| Portuguese | pt | 葡萄牙语 |
| Spanish | es | 西班牙语 |
| Japanese | ja | 日语 |
| Turkish | tr | 土耳其语 |
| Russian | ru | 俄语 |
| Arabic | ar | 阿拉伯语 |
| Korean | ko | 韩语 |
| Thai | th | 泰语 |
| Italian | it | 意大利语 |
| German | de | 德语 |
| Vietnamese | vi | 越南语 |
| Malay | ms | 马来语 |
| Indonesian | id | 印尼语 |
| Filipino | tl | 菲律宾语 |
| Hindi | hi | 印地语 |
| Traditional Chinese | zh-Hant | 繁体中文 |
| Polish | pl | 波兰语 |
| Czech | cs | 捷克语 |
| Dutch | nl | 荷兰语 |
| Khmer | km | 高棉语 |
| Burmese | my | 缅甸语 |
| Persian | fa | 波斯语 |
| Gujarati | gu | 古吉拉特语 |
| Urdu | ur | 乌尔都语 |
| Telugu | te | 泰卢固语 |
| Marathi | mr | 马拉地语 |
| Hebrew | he | 希伯来语 |
| Bengali | bn | 孟加拉语 |
| Tamil | ta | 泰米尔语 |
| Ukrainian | uk | 乌克兰语 |
| Tibetan | bo | 藏语 |
| Kazakh | kk | 哈萨克语 |
| Mongolian | mn | 蒙古语 |
| Uyghur | ug | 维吾尔语 |
| Cantonese | yue | 粤语 |

## 非目标

- 不手填模型路径
- 不输入任意 URL 下载
- 不做多模型市场
- 不提交 GGUF 到 Git
- 不用 CLI 模式作为产品架构
- 当前阶段不做 iOS（侧载体验差）
- 不上架 App Store / Google Play
- 不把 Android `.so` 直接复用为 HarmonyOS NEXT 原生产物

## 技术约束

- 推理路线：Flutter UI + shared native `translator_engine` + thin platform bridge
- HarmonyOS NEXT 推理路线：Flutter on OHOS（首选）或 ArkTS/ArkUI + NAPI（备选）+ shared native `translator_engine`
- 默认模型：`Hy-MT1.5-1.8B-STQ1_0.gguf`
- `llama.cpp` 必须保持 PR #22836 STQ1_0 兼容
- Hy-MT2 1.25bit 与 2bit 依赖不同 `llama.cpp` 兼容路径：1.25bit / `STQ1_0` 需要 PR #22836；2bit / `q2_0c` 需要 PR #19357。不能把其中一个 PR runtime 当成另一个量化格式的替代实现。
- 若产品要同时支持 Hy-MT2 1.25bit 和 2bit，需要合并 PR #22836 与 PR #19357 的 ggml / llama.cpp 改动，并重新完成 macOS、Android 的加载与最小翻译验证。
- 原生引擎复用 `llama.cpp/common` chat template / tokenize / sampler
- Android 仅 `arm64-v8a`
- HarmonyOS NEXT 仅 ARM64 / AArch64，需用 OHOS Native SDK 重新编译 native 依赖

## 技术债务

### 多语言排版方向

当前 UI 默认按横排、从左到右文本处理。多语言扩展后需要补齐不同书写方向的排版能力：

- `蒙古语 (mn)`：本项目按传统蒙古文处理。当前模型输出字形已能正常显示，首版可先在译文区域提供 90° 旋转显示模式；输入框、语言选择栏、按钮仍保持常规横排。复制内容必须保持原始文本顺序，不受视觉旋转影响。后续再评估是否需要真正的传统蒙古文竖排排版引擎。
- `阿拉伯语 (ar)`、`波斯语 (fa)`、`乌尔都语 (ur)`、`希伯来语 (he)`：需要支持从右到左（RTL）排版。
- 语言选择、输入框、译文输出、复制内容和流式渲染都应按语言方向应用一致规则。
- 在实现前，需确认 Flutter Android / macOS / Web / HarmonyOS Flutter on OHOS 对 RTL、旋转显示和真正竖排排版的支持差异。
