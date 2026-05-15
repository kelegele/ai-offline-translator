# macOS ModelScope Downloader Design

## Context

The macOS app can currently load a local GGUF file through the native `TranslatorBridge` / `TranslatorEngine`, and it can import a user-selected GGUF into the app-private models directory:

```text
~/Library/Application Support/ai_offline_translator/models/
```

This still leaves model acquisition outside the app. Before Android work starts, macOS should complete the same product loop as the official Hy-MT demo: the runtime ships without the large GGUF model, downloads the model from ModelScope into app-private storage, then loads the model from that local file path.

The reference report is `models/AngelSlim/Hy-MT-demo-apk-technical-report.md`. The official demo uses ModelScope `resolve/master/...gguf` URLs, downloads into app-private `files/models/`, supports progress and cancellation, and does not package the model inside the app.

## Goal

Add a macOS in-app downloader for the default validated model:

```text
Hy-MT1.5-1.8B-STQ1_0.gguf
```

The downloader should fetch from ModelScope, save into macOS Application Support, show progress in the existing model panel, allow cancellation, and leave model loading as an explicit user action.

## Non-Goals

- No Android downloader in this step.
- No multi-model catalog UI.
- No resumable downloads in the first version.
- No automatic model load after download.
- No HuggingFace fallback in the first version.
- No model file committed to git.

## Model Definition

The app should embed a single default model record:

```text
id: hymt15_18b_stq10
displayName: Hy-MT1.5 1.8B STQ1_0
filename: Hy-MT1.5-1.8B-STQ1_0.gguf
downloadUrl: https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf
storageDir: ~/Library/Application Support/ai_offline_translator/models/
```

The `STQ1_0` file is the only model that has been validated with the current `llama.cpp` PR #22836 path. The app should not download `Hy-MT1.5-1.8B-1.25bit.gguf` by default because that file previously failed local compatibility checks.

## User Flow

1. User opens the macOS app.
2. Model panel shows read-only selected model name, `导入模型`, and `下载模型`.
3. If the default model already exists in Application Support and passes the GGUF magic check, clicking `下载模型` should select the existing file without downloading again.
4. If the model is missing, clicking `下载模型` starts a ModelScope download.
5. The model panel shows progress as bytes or MB, plus `取消下载`.
6. On cancellation, the temporary partial file is removed and the current model selection is unchanged.
7. On success, the downloaded GGUF is moved into Application Support and selected internally; the UI only displays the model filename.
8. User clicks `加载模型`.
9. Existing native engine loads the file and translation proceeds.

## Flutter API

Extend the existing translator `MethodChannel`:

```text
getDefaultModelInfo() -> Map
downloadDefaultModel() -> String? finalPath
cancelModelDownload() -> void
getModelDownloadStatus() -> Map
```

The first implementation should use polling from Flutter rather than an `EventChannel`. Polling is enough for a single download, avoids adding another platform channel, and is easier to mirror on Android later.

`getModelDownloadStatus()` should return:

```text
state: idle | downloading | completed | cancelled | failed
receivedBytes: int
totalBytes: int
message: String
path: String?
```

## macOS Native Design

`TranslatorChannelHandler.swift` should own the macOS download task because it already owns model file selection and Application Support path resolution.

Implementation details:

- Use `URLSessionDownloadTask`, not `Data(contentsOf:)`, so the 440MB-scale file is not loaded into memory.
- Use a delegate-based `URLSession` to receive progress.
- Download into a temporary system file provided by `URLSession`.
- Validate the completed file before moving it:
  - extension is `.gguf`
  - first four bytes are `GGUF`
  - file size is greater than a conservative lower bound such as 100MB
- Move with replacement only after validation succeeds.
- Store the final file at:

```text
~/Library/Application Support/ai_offline_translator/models/Hy-MT1.5-1.8B-STQ1_0.gguf
```

- Do not delete a previously valid final model if a new download fails.
- On cancellation, delete only temporary partial files.

## Flutter UI Design

Follow `DESIGN.md` and the current model panel style:

- Keep the current card layout.
- Add `下载模型` next to `导入模型`.
- While downloading:
  - disable `下载模型`
  - show `取消下载`
  - show progress text under the buttons, e.g. `正在下载：128 MB / 436 MB`
- On success:
  - set the path text field to the downloaded file path
  - call `selectModel(path)`
  - show runtime status `模型已下载，等待加载`
- On failure:
  - show an error in the existing model error area
  - keep any previous selected path unchanged

## Error Handling

The downloader should surface clear user-facing errors:

- Network unavailable or timeout: `模型下载失败，请检查网络后重试。`
- User cancellation: `下载已取消。`
- Invalid file: `下载文件不是有效的 GGUF 模型。`
- File move failure: `模型保存失败，请检查磁盘空间。`

Native details can remain in logs; the UI should not dump raw stack traces.

## Testing

Flutter tests should cover controller/UI state where practical:

- Default model download success selects the returned path.
- Download failure surfaces a model error.
- Cancel download calls the service/channel and returns to a non-downloading state.

Manual validation is required for the real 440MB download:

```bash
cd flutter_app
flutter analyze
flutter test
flutter build macos
flutter run -d macos
```

Manual app validation:

1. Delete or move the existing Application Support model.
2. Click `下载模型`.
3. Confirm progress updates.
4. Cancel once and confirm partial download does not become selected.
5. Start again and wait for completion.
6. Click `加载模型`.
7. Translate `Hello` to Chinese and confirm a non-garbled result.

## Rollout Notes

This macOS downloader establishes the same runtime-file model contract needed for Android:

```text
model catalog entry -> app-private models directory -> native engine loads file path
```

After this lands, Android should implement the same model record and state machine, with the Android target directory changed to `context.filesDir/models/`.
