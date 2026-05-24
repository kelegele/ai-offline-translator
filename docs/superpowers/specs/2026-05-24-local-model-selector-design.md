# 本地模型选择器设计

## 背景

当前 App 的模型流程是单模型状态：导入或下载一个 GGUF 后进入“已选择，等待加载”，用户点击“加载”后 native engine 加载该路径。启动时 native 侧只返回第一个本地 GGUF，因此当 App 私有 `models/` 目录中存在多个模型时，用户无法明确选择要加载哪一个。

Hy-MT2 引入后，本项目会同时保留 Hy-MT1.5、Hy-MT2 1.25bit 以及后续 2bit 实验模型。本地模型选择器的第一版目标是让用户在本地 GGUF 文件之间单选，并明确加载哪一个模型。

## 产品边界

第一版做“模型切换面板内的本地模型选择器”，不新开页面，不做模型市场，不做多模型同时加载，不做 2bit runtime 自动切换。

- 支持在现有模型 bottom sheet 内展示“支持的模型列表”。
- 支持用户单选一个已下载的模型。
- 支持对选中模型执行加载。
- 支持导入模型后刷新列表并自动选中新导入模型。
- 支持本地没有模型时在模型列表中直接下载默认支持模型。
- 默认下载模型切到 Hy-MT2 1.25bit GGUF，优先使用国内可访问的 HF-Mirror 地址。
- 第一版按当前 `llama.cpp` PR #22836 / `STQ1_0` runtime 设计，优先支持 Hy-MT2 1.25bit。
- 去掉现有操作区里的独立“下载”按钮；下载入口移动到模型列表行的单选位置。

不在第一版范围内：

- 不支持 2bit 作为默认模型。Hy-MT2 2bit 需要 `llama.cpp` PR #19357 / `q2_0c`，不能用当前 runtime 直接加载。
- 不做远程模型列表、模型市场、版本推荐或自动选择最佳量化。
- 不在 UI 中展示完整本地路径。

## 默认下载源

第一版支持模型列表：

- 名称：`Hy-MT2 1.8B 1.25bit`
- 文件名：`Hy-MT2-1.8B-1.25Bit.gguf`
- 下载地址：`https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF/resolve/main/Hy-MT2-1.8B-1.25Bit.gguf`

仍保留 GGUF magic header 校验和最小文件大小校验。后续可补 SHA256 校验，但第一版不阻塞在 SHA256 上。

## 用户流程

### 启动扫描

1. App 启动后调用 native channel 扫描 App 私有 `models/` 目录。
2. Flutter 将扫描结果与“支持的模型列表”按文件名匹配。
3. 若支持模型已下载，该行显示单选控件，可被选中。
4. 若支持模型未下载，该行不能单选；单选控件位置显示下载 icon。
5. 若没有任何已下载模型，模型面板显示空状态：“请下载或导入模型”，但不再显示独立“下载”按钮。
6. 若只有一个已下载模型，自动选中该模型，但不改变现有“用户点击加载”的可控流程。
7. 若有多个已下载模型，自动选中当前已加载模型；若没有已加载模型，选中第一个稳定排序后的已下载模型。

### 导入模型

1. 用户点击“导入”。
2. native picker 选择 `.gguf`。
3. native 复制到 App 私有 `models/` 目录，并校验 GGUF magic header。
4. Flutter 刷新本地模型列表。
5. 自动选中新导入模型。
6. 用户点击“加载”后加载该模型。

### 下载模型

1. 用户点击未下载模型行左侧的下载 icon。
2. App 从该行配置的下载地址下载模型。第一版为 HF-Mirror 上的 Hy-MT2 1.25bit GGUF。
3. 下载过程沿用现有进度、取消、失败提示。
4. 下载完成后保存到 App 私有 `models/` 目录。
5. Flutter 刷新本地模型列表。
6. 自动选中新下载模型。
7. 用户点击“加载”后加载该模型。
8. 下载中该行左侧显示 loading 状态，不允许重复触发下载。

### 切换模型

1. 用户在模型列表中单选另一个已下载模型。
2. 若当前已有模型加载，状态显示“已选择，等待加载”。
3. 用户点击“加载”。
4. Controller 先调用 `unloadModel()`，再调用 `loadModel(path)`。
5. 成功后该模型标记为“已加载”；失败时保留选中状态并展示错误。

## UI 设计

模型选择器直接在现有模型 bottom sheet 内实现，不新开页面。

结构：

- 顶部：标题“模型”
- 当前状态块：显示当前选中模型名、加载状态、错误提示
- 支持模型列表：展示可用模型及其下载状态
- 操作区：导入、取消下载、加载、卸载
- 下载反馈：沿用当前进度 / 完成 / 取消 / 失败文案，并保留在原来的位置

模型列表行：

- 已下载模型左侧：单选标识
- 未下载模型左侧：下载 icon，点击后开始下载该行模型
- 下载中模型左侧：loading 指示
- 主文本：模型显示名
- 副文本：文件大小和状态，例如“440 MB · 已加载”或“未下载”
- 已加载模型使用成功色
- 加载失败错误显示在状态块，不在每一行塞长文案
- 顶层独立“下载”按钮移除，避免和行内下载入口重复

下载反馈文案：

- 仍使用现有 `ModelDownloadState` 和原来的展示位置。
- 只有用户点击行内下载 icon 后才显示。
- 文案继续沿用“正在连接 ModelScope / 正在下载模型 / 模型已下载 / 下载已取消 / 下载失败”等现有状态文案。即使下载源换成 HF-Mirror，第一版不强行重写所有历史文案；可在后续统一改为“正在连接下载源”。

视觉遵循 `DESIGN.md`：工具型界面、低装饰密度、8-10px 圆角、当前 MiniMax 风格颜色和现有 App spacing。

## 数据结构

新增 Dart model：

```dart
class LocalModelInfo {
  const LocalModelInfo({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}
```

新增支持模型配置：

```dart
class SupportedModelInfo {
  const SupportedModelInfo({
    required this.id,
    required this.displayName,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSizeLabel,
  });

  final String id;
  final String displayName;
  final String filename;
  final String downloadUrl;
  final String expectedSizeLabel;
}
```

扩展 `ModelSelectionState`：

- `availableModels: List<LocalModelInfo>`
- `supportedModels: List<SupportedModelInfo>`
- `downloadingModelId`
- `selectedPath`
- `displayName`
- `loadedPath`
- `status`
- `errorMessage`

`selectedPath` 表示用户当前单选项。`loadedPath` 表示 native engine 当前实际加载的模型。两者不同，则 UI 显示“已选择，等待加载”。

未下载的支持模型没有 `selectedPath`，不能被选中；点击其行首下载 icon 只启动下载。

## Native Channel

新增方法：

```text
listLocalModels -> List<Map<String, Object?>>
```

返回字段：

- `path`
- `name`
- `sizeBytes`

macOS 与 Android 都从 App 私有 `models/` 目录读取 `.gguf` 文件，过滤隐藏文件，并按文件名稳定排序。保留现有 `findLocalModel` 以降低改动风险，但 Flutter 侧启动逻辑改用 `listLocalModels`。

下载方法可以继续复用现有 `downloadDefaultModel`，但内部默认模型信息改为 Hy-MT2 1.25bit 的 HF-Mirror 地址。若后续支持多个远程模型，再扩展为 `downloadModel(id)`。

## Controller 行为

新增方法：

- `refreshLocalModels({String? preferredPath})`
- `selectLocalModel(LocalModelInfo model)`
- `downloadSupportedModel(SupportedModelInfo model)`

调整方法：

- `loadSelectedModel()`：如果 `loadedPath != selectedPath`，先卸载旧模型，再加载新模型。
- `startModelDownload(path)`：下载完成后刷新列表并选中新路径。
- 导入成功路径：刷新列表并选中新路径。

错误处理：

- 扫描失败：列表置空，保留导入入口和支持模型行内下载入口。
- 未下载模型被点击时不改变选中项，只触发下载。
- 加载失败：状态为 failed，保留 selectedPath，显示 native 错误。
- 下载失败：沿用当前下载失败状态，不改变已加载模型。

## 测试计划

Controller 单元测试先行：

- 扫描多个模型后默认选中第一个。
- `preferredPath` 存在时优先选中该模型。
- 用户选择第二个模型后 selectedPath 更新，loadedPath 不变。
- 未下载模型不能被单选，点击其下载 icon 会进入下载状态。
- 加载选中模型时传入正确 path。
- 已加载 A，再加载 B，会先 unload 再 load B。
- 加载失败保留选中模型并显示错误。
- 下载完成后刷新列表并选中新下载模型。

Channel 相关测试：

- Dart channel 能解析 `listLocalModels` 返回列表。
- 空列表时 UI 仍显示导入入口，并在支持模型行显示下载 icon。

手动验证：

- macOS：空目录下载 Hy-MT2 1.25bit 后加载并翻译 `hello -> 你好`。
- macOS：导入两个 GGUF 后切换选择并加载。
- Android：同样验证导入、下载、单选加载。未完成真机验证前不打 tag。

## 后续

2bit 支持需要单独 runtime 工作：合并 `llama.cpp` PR #22836 的 `STQ1_0` 与 PR #19357 的 `q2_0c`。本地模型选择器只负责让用户选择文件，不保证当前 runtime 能加载所有 GGUF。加载失败必须清楚反馈给用户。
