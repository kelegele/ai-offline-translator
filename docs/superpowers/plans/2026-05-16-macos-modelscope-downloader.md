# macOS ModelScope Downloader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS in-app ModelScope downloader for the validated `Hy-MT1.5-1.8B-STQ1_0.gguf` model.

**Architecture:** Flutter keeps the existing model panel and controller, adding a small download state machine and polling native progress. macOS owns the actual `URLSessionDownloadTask`, validates the completed GGUF file, stores it in Application Support, and returns the final path for explicit user loading.

**Tech Stack:** Flutter/Dart, Flutter MethodChannel, Swift `URLSessionDownloadDelegate`, macOS Application Support, existing native `TranslatorBridge`.

---

## File Map

- Modify `flutter_app/lib/features/translator/model_download_state.dart`: new Dart value object for download status.
- Modify `flutter_app/lib/features/translator/translator_channel.dart`: add download channel methods.
- Modify `flutter_app/lib/features/translator/translator_controller.dart`: add download/cancel polling state.
- Modify `flutter_app/lib/features/translator/translator_state.dart`: carry download state.
- Modify `flutter_app/lib/features/translator/translator_page.dart`: add `下载模型`, `取消下载`, and progress text.
- Modify `flutter_app/macos/Runner/TranslatorChannelHandler.swift`: implement ModelScope download task, status, cancel, and validation.
- Modify `flutter_app/test/features/translator/translator_controller_test.dart`: test download success, failure, and cancellation.
- Modify `flutter_app/test/widget_test.dart`: assert the model panel exposes the download action.
- Modify `README.md` and `CHANGELOG.md`: document the downloader.

## Task 1: Add Dart Download State

**Files:**
- Create: `flutter_app/lib/features/translator/model_download_state.dart`
- Modify: `flutter_app/lib/features/translator/translator_state.dart`

- [ ] **Step 1: Create the download status type**

Create `flutter_app/lib/features/translator/model_download_state.dart`:

```dart
enum ModelDownloadStatus { idle, downloading, completed, cancelled, failed }

class ModelDownloadState {
  const ModelDownloadState({
    this.status = ModelDownloadStatus.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message = '',
    this.path,
  });

  final ModelDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String message;
  final String? path;

  bool get isDownloading => status == ModelDownloadStatus.downloading;

  String get progressLabel {
    if (totalBytes <= 0) {
      return receivedBytes <= 0 ? message : '正在下载：${_formatBytes(receivedBytes)}';
    }
    return '正在下载：${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}';
  }

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? message,
    String? path,
    bool clearPath = false,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      message: message ?? this.message,
      path: clearPath ? null : path ?? this.path,
    );
  }

  static String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 100) {
      return '${mb.toStringAsFixed(0)} MB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}
```

- [ ] **Step 2: Wire state into `TranslatorState`**

Modify `flutter_app/lib/features/translator/translator_state.dart`:

```dart
import 'model_download_state.dart';
import 'model_selection_state.dart';
```

Add constructor field:

```dart
this.modelDownloadState = const ModelDownloadState(),
```

Add class field:

```dart
final ModelDownloadState modelDownloadState;
```

Add `copyWith` parameter:

```dart
ModelDownloadState? modelDownloadState,
```

Pass it through:

```dart
modelDownloadState: modelDownloadState ?? this.modelDownloadState,
```

- [ ] **Step 3: Run targeted tests**

Run:

```bash
cd flutter_app
flutter test test/features/translator/translator_controller_test.dart
```

Expected: tests still pass.

- [ ] **Step 4: Commit**

```bash
git add flutter_app/lib/features/translator/model_download_state.dart flutter_app/lib/features/translator/translator_state.dart
git commit -m "Add model download state"
```

## Task 2: Extend Channel and Controller

**Files:**
- Modify: `flutter_app/lib/features/translator/translator_channel.dart`
- Modify: `flutter_app/lib/features/translator/translator_controller.dart`
- Modify: `flutter_app/test/features/translator/translator_controller_test.dart`

- [ ] **Step 1: Add failing controller tests**

Extend fake services in `flutter_app/test/features/translator/translator_controller_test.dart` only if needed for constructor compatibility.

Append tests:

```dart
test('download default model selects returned path', () async {
  final controller = TranslatorController(
    service: RecordingTranslatorService(),
  );

  controller.startModelDownload('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');

  expect(
    controller.state.modelState.selectedPath,
    '/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf',
  );
  expect(controller.state.runtimeStatus, '模型已下载，等待加载');
});

test('download failure surfaces model error', () {
  final controller = TranslatorController(
    service: RecordingTranslatorService(),
  );

  controller.failModelDownload('模型下载失败，请检查网络后重试。');

  expect(controller.state.status, TranslatorStatus.error);
  expect(
    controller.state.modelState.errorMessage,
    '模型下载失败，请检查网络后重试。',
  );
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd flutter_app
flutter test test/features/translator/translator_controller_test.dart
```

Expected: fails because `startModelDownload` and `failModelDownload` are not defined.

- [ ] **Step 3: Add channel methods**

Modify `flutter_app/lib/features/translator/translator_channel.dart`:

```dart
Future<Map<String, Object?>> getDefaultModelInfo() async {
  final result = await _channel.invokeMapMethod<String, Object?>(
    'getDefaultModelInfo',
  );
  return result ?? const {};
}

Future<String?> downloadDefaultModel() {
  return _channel.invokeMethod<String>('downloadDefaultModel');
}

Future<void> cancelModelDownload() async {
  await _channel.invokeMethod<void>('cancelModelDownload');
}

Future<Map<String, Object?>> getModelDownloadStatus() async {
  final result = await _channel.invokeMapMethod<String, Object?>(
    'getModelDownloadStatus',
  );
  return result ?? const {};
}
```

- [ ] **Step 4: Add controller download helpers**

Modify `flutter_app/lib/features/translator/translator_controller.dart`:

```dart
import 'model_download_state.dart';
```

Add methods:

```dart
void beginModelDownload() {
  _state = _state.copyWith(
    runtimeStatus: '正在下载模型',
    modelDownloadState: const ModelDownloadState(
      status: ModelDownloadStatus.downloading,
      message: '正在连接 ModelScope',
    ),
    clearError: true,
  );
  notifyListeners();
}

void updateModelDownloadProgress({
  required int receivedBytes,
  required int totalBytes,
  required String message,
}) {
  _state = _state.copyWith(
    runtimeStatus: '正在下载模型',
    modelDownloadState: ModelDownloadState(
      status: ModelDownloadStatus.downloading,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      message: message,
    ),
  );
  notifyListeners();
}

void startModelDownload(String path) {
  selectModel(path);
  _state = _state.copyWith(
    runtimeStatus: '模型已下载，等待加载',
    modelDownloadState: ModelDownloadState(
      status: ModelDownloadStatus.completed,
      path: path,
      message: '模型已下载',
    ),
    clearError: true,
  );
  notifyListeners();
}

void cancelModelDownload() {
  _state = _state.copyWith(
    runtimeStatus: '下载已取消',
    modelDownloadState: const ModelDownloadState(
      status: ModelDownloadStatus.cancelled,
      message: '下载已取消。',
    ),
  );
  notifyListeners();
}

void failModelDownload(String message) {
  _state = _state.copyWith(
    status: TranslatorStatus.error,
    runtimeStatus: '模型下载失败',
    modelDownloadState: ModelDownloadState(
      status: ModelDownloadStatus.failed,
      message: message,
    ),
    modelState: _state.modelState.copyWith(
      status: ModelLifecycleStatus.failed,
      errorMessage: message,
    ),
    errorMessage: message,
  );
  notifyListeners();
}
```

- [ ] **Step 5: Run targeted tests**

Run:

```bash
cd flutter_app
flutter test test/features/translator/translator_controller_test.dart
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add flutter_app/lib/features/translator/translator_channel.dart flutter_app/lib/features/translator/translator_controller.dart flutter_app/test/features/translator/translator_controller_test.dart
git commit -m "Add model download controller flow"
```

## Task 3: Implement macOS Native Downloader

**Files:**
- Modify: `flutter_app/macos/Runner/TranslatorChannelHandler.swift`

- [ ] **Step 1: Add native constants and state**

In `TranslatorChannelHandler`, add:

```swift
private let defaultModelFilename = "Hy-MT1.5-1.8B-STQ1_0.gguf"
private let defaultModelURL = URL(string: "https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf")!
private let minimumModelBytes: Int64 = 100 * 1024 * 1024
private var downloadTask: URLSessionDownloadTask?
private var downloadStatus: [String: Any] = [
  "state": "idle",
  "receivedBytes": 0,
  "totalBytes": 0,
  "message": "",
  "path": NSNull()
]
private lazy var downloadSession = URLSession(
  configuration: .default,
  delegate: self,
  delegateQueue: nil
)
private var pendingDownloadResult: FlutterResult?
```

- [ ] **Step 2: Add method channel cases**

Add cases in `handle`:

```swift
case "getDefaultModelInfo":
  result(defaultModelInfo())
case "downloadDefaultModel":
  downloadDefaultModel(result: result)
case "cancelModelDownload":
  cancelModelDownload()
  result(nil)
case "getModelDownloadStatus":
  result(downloadStatus)
```

- [ ] **Step 3: Add model path helpers**

Add:

```swift
private func defaultModelInfo() -> [String: Any] {
  return [
    "id": "hymt15_18b_stq10",
    "displayName": "Hy-MT1.5 1.8B STQ1_0",
    "filename": defaultModelFilename,
    "downloadUrl": defaultModelURL.absoluteString
  ]
}

private func modelsDirectoryURL() throws -> URL {
  let supportURL = try FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
  )
  let modelsURL = supportURL
    .appendingPathComponent("ai_offline_translator", isDirectory: true)
    .appendingPathComponent("models", isDirectory: true)
  try FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
  return modelsURL
}

private func defaultModelDestinationURL() throws -> URL {
  return try modelsDirectoryURL().appendingPathComponent(defaultModelFilename)
}
```

- [ ] **Step 4: Refactor import helper to reuse models directory**

In `copyModelToAppSupport`, replace inline Application Support directory creation with:

```swift
let modelsURL = try modelsDirectoryURL()
```

- [ ] **Step 5: Add download start/cancel**

Add:

```swift
private func downloadDefaultModel(result: @escaping FlutterResult) {
  do {
    let destinationURL = try defaultModelDestinationURL()
    if FileManager.default.fileExists(atPath: destinationURL.path),
       isValidGGUF(at: destinationURL, minimumBytes: minimumModelBytes) {
      updateDownloadStatus(state: "completed", receivedBytes: 0, totalBytes: 0, message: "模型已存在", path: destinationURL.path)
      result(destinationURL.path)
      return
    }
  } catch {
    result(FlutterError(code: "download_failed", message: "模型保存失败，请检查磁盘空间。", details: nil))
    return
  }

  if downloadTask != nil {
    result(FlutterError(code: "download_in_progress", message: "模型正在下载。", details: nil))
    return
  }

  pendingDownloadResult = result
  updateDownloadStatus(state: "downloading", receivedBytes: 0, totalBytes: 0, message: "正在连接 ModelScope", path: nil)
  let task = downloadSession.downloadTask(with: defaultModelURL)
  downloadTask = task
  task.resume()
}

private func cancelModelDownload() {
  downloadTask?.cancel()
  downloadTask = nil
  updateDownloadStatus(state: "cancelled", receivedBytes: 0, totalBytes: 0, message: "下载已取消。", path: nil)
  pendingDownloadResult?(nil)
  pendingDownloadResult = nil
}
```

- [ ] **Step 6: Add validation/status helpers**

Add:

```swift
private func isValidGGUF(at url: URL, minimumBytes: Int64 = 0) -> Bool {
  guard url.pathExtension.lowercased() == "gguf" else { return false }
  guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        Int64(size) >= minimumBytes else { return false }
  guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
  defer { handle.closeFile() }
  return handle.readData(ofLength: 4) == Data([0x47, 0x47, 0x55, 0x46])
}

private func updateDownloadStatus(
  state: String,
  receivedBytes: Int64,
  totalBytes: Int64,
  message: String,
  path: String?
) {
  downloadStatus = [
    "state": state,
    "receivedBytes": receivedBytes,
    "totalBytes": totalBytes,
    "message": message,
    "path": path ?? NSNull()
  ]
}
```

- [ ] **Step 7: Add URLSession delegate extension**

At the end of `TranslatorChannelHandler.swift`, add:

```swift
extension TranslatorChannelHandler: URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    updateDownloadStatus(
      state: "downloading",
      receivedBytes: totalBytesWritten,
      totalBytes: max(totalBytesExpectedToWrite, 0),
      message: "正在下载模型",
      path: nil
    )
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    do {
      let destinationURL = try defaultModelDestinationURL()
      guard isValidGGUF(at: location, minimumBytes: minimumModelBytes) else {
        throw NSError(domain: "Translator", code: 21, userInfo: [NSLocalizedDescriptionKey: "下载文件不是有效的 GGUF 模型。"])
      }
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
      }
      try FileManager.default.moveItem(at: location, to: destinationURL)
      updateDownloadStatus(
        state: "completed",
        receivedBytes: 0,
        totalBytes: 0,
        message: "模型已下载",
        path: destinationURL.path
      )
      DispatchQueue.main.async {
        self.pendingDownloadResult?(destinationURL.path)
        self.pendingDownloadResult = nil
        self.downloadTask = nil
      }
    } catch {
      updateDownloadStatus(
        state: "failed",
        receivedBytes: 0,
        totalBytes: 0,
        message: error.localizedDescription,
        path: nil
      )
      DispatchQueue.main.async {
        self.pendingDownloadResult?(FlutterError(code: "download_failed", message: error.localizedDescription, details: nil))
        self.pendingDownloadResult = nil
        self.downloadTask = nil
      }
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error = error as NSError? else { return }
    if error.code == NSURLErrorCancelled { return }
    updateDownloadStatus(
      state: "failed",
      receivedBytes: 0,
      totalBytes: 0,
      message: "模型下载失败，请检查网络后重试。",
      path: nil
    )
    DispatchQueue.main.async {
      self.pendingDownloadResult?(FlutterError(code: "download_failed", message: "模型下载失败，请检查网络后重试。", details: nil))
      self.pendingDownloadResult = nil
      self.downloadTask = nil
    }
  }
}
```

- [ ] **Step 8: Build macOS**

Run:

```bash
cd flutter_app
flutter build macos
```

Expected: build succeeds.

- [ ] **Step 9: Commit**

```bash
git add flutter_app/macos/Runner/TranslatorChannelHandler.swift
git commit -m "Add macOS ModelScope downloader bridge"
```

## Task 4: Add Flutter UI Download Flow

**Files:**
- Modify: `flutter_app/lib/features/translator/translator_page.dart`
- Modify: `flutter_app/test/widget_test.dart`

- [ ] **Step 1: Update widget test expectation**

Modify `flutter_app/test/widget_test.dart`:

```dart
expect(find.text('下载模型'), findsOneWidget);
```

- [ ] **Step 2: Add page polling helpers**

In `_TranslatorPageState`, add a timer:

```dart
Timer? _downloadPollTimer;
```

Import:

```dart
import 'dart:async';
import 'model_download_state.dart';
```

Dispose it:

```dart
_downloadPollTimer?.cancel();
```

Add:

```dart
Future<void> _downloadDefaultModel() async {
  _controller.beginModelDownload();
  _startDownloadPolling();
  try {
    final path = await _translatorChannel.downloadDefaultModel();
    _downloadPollTimer?.cancel();
    if (path == null || path.trim().isEmpty) {
      _controller.cancelModelDownload();
      return;
    }
    _modelPathController.text = path;
    _controller.startModelDownload(path);
  } on Object {
    _downloadPollTimer?.cancel();
    _controller.failModelDownload('模型下载失败，请检查网络后重试。');
  }
}

Future<void> _cancelModelDownload() async {
  await _translatorChannel.cancelModelDownload();
  _downloadPollTimer?.cancel();
  _controller.cancelModelDownload();
}

void _startDownloadPolling() {
  _downloadPollTimer?.cancel();
  _downloadPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
    final status = await _translatorChannel.getModelDownloadStatus();
    final state = status['state'] as String? ?? 'idle';
    if (state != 'downloading') {
      return;
    }
    _controller.updateModelDownloadProgress(
      receivedBytes: status['receivedBytes'] as int? ?? 0,
      totalBytes: status['totalBytes'] as int? ?? 0,
      message: status['message'] as String? ?? '正在下载模型',
    );
  });
}
```

- [ ] **Step 3: Pass callbacks into model panel**

Update `_ModelPanel` call:

```dart
onDownloadPressed: Platform.isMacOS ? _downloadDefaultModel : null,
onCancelDownloadPressed: state.modelDownloadState.isDownloading
    ? _cancelModelDownload
    : null,
```

- [ ] **Step 4: Add model panel buttons/progress**

Add constructor fields:

```dart
required this.onDownloadPressed,
required this.onCancelDownloadPressed,
```

Add fields:

```dart
final Future<void> Function()? onDownloadPressed;
final Future<void> Function()? onCancelDownloadPressed;
```

In the button row, insert after `导入模型`:

```dart
const SizedBox(width: AppSpacing.sm),
OutlinedButton(
  onPressed: state.modelDownloadState.isDownloading ? null : onDownloadPressed,
  child: const Text('下载模型'),
),
if (state.modelDownloadState.isDownloading) ...[
  const SizedBox(width: AppSpacing.sm),
  OutlinedButton(
    onPressed: onCancelDownloadPressed,
    child: const Text('取消下载'),
  ),
],
```

Below the row, add:

```dart
if (state.modelDownloadState.isDownloading) ...[
  const SizedBox(height: AppSpacing.sm),
  Text(
    state.modelDownloadState.progressLabel,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.steel,
    ),
  ),
],
```

- [ ] **Step 5: Run tests**

Run:

```bash
cd flutter_app
flutter test test/widget_test.dart
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add flutter_app/lib/features/translator/translator_page.dart flutter_app/test/widget_test.dart
git commit -m "Add model downloader UI"
```

## Task 5: Validate and Document

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/validation_status_2026-05-16.md`

- [ ] **Step 1: Update README**

In `README.md`, update the macOS instructions to mention:

```text
点击“下载模型”可从 ModelScope 下载 Hy-MT1.5-1.8B-STQ1_0.gguf 到：
~/Library/Application Support/ai_offline_translator/models/
```

- [ ] **Step 2: Update CHANGELOG**

Add under unreleased or `v0.0.1` development notes:

```text
- Added macOS ModelScope downloader for the default STQ1_0 GGUF model.
```

- [ ] **Step 3: Update validation status**

Add validation notes to `docs/validation_status_2026-05-16.md`:

```text
- macOS downloader builds and exposes ModelScope download controls.
- Real network download must be manually verified because it transfers a 440MB-scale model.
```

- [ ] **Step 4: Run full validation**

Run:

```bash
cd flutter_app
flutter analyze
flutter test
flutter build macos
```

Expected: all pass. Linker SDK warnings are acceptable if build succeeds.

- [ ] **Step 5: Manual smoke**

Run:

```bash
cd flutter_app
flutter run -d macos
```

Manual expected behavior:

- `下载模型` starts progress.
- `取消下载` cancels without selecting a partial file.
- successful download selects the Application Support path.
- loading the downloaded model works.
- `Hello` translates to Chinese without garbled output.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md docs/validation_status_2026-05-16.md
git commit -m "Document macOS model downloader"
```
