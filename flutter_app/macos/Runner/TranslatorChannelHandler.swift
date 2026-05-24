import Foundation
import FlutterMacOS
import UniformTypeIdentifiers

final class TranslatorChannelHandler: NSObject {
  private let channelName = "ai_offline_translator/translator"
  private let bridge = TranslatorBridge()
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

  func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickModelFile":
      pickModelFile(result: result)
    case "importModelFile":
      importModelFile(result: result)
    case "getDefaultModelInfo":
      result(defaultModelInfo())
    case "downloadDefaultModel":
      downloadDefaultModel(result: result)
    case "cancelModelDownload":
      cancelModelDownload()
      result(nil)
    case "getModelDownloadStatus":
      result(downloadStatus)
    case "findLocalModel":
      findLocalModel(result: result)
    case "listLocalModels":
      listLocalModels(result: result)
    case "loadModel":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let nCtx = args["nCtx"] as? Int,
            let nThreads = args["nThreads"] as? Int else {
        result(FlutterError(code: "bad_args", message: "缺少模型加载参数", details: nil))
        return
      }
      if !FileManager.default.fileExists(atPath: path) {
        result(FlutterError(code: "load_failed", message: "模型文件不存在：\(path)", details: nil))
        return
      }
      if !bridge.load(withPath: path, nCtx: nCtx, nThreads: nThreads) {
        result(FlutterError(code: "load_failed", message: bridge.lastError() ?? "模型加载失败", details: nil))
        return
      }
      result(nil)
    case "translate":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let sourceLanguage = args["sourceLanguage"] as? String,
            let targetLanguage = args["targetLanguage"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少翻译参数", details: nil))
        return
      }
      translateNative(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, result: result)
    case "beginTranslation":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let sourceLanguage = args["sourceLanguage"] as? String,
            let targetLanguage = args["targetLanguage"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少翻译参数", details: nil))
        return
      }
      handleBeginTranslation(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, result: result)
    case "generateNextToken":
      handleGenerateNextToken(result: result)
    case "cancel":
      bridge.cancel()
      result(nil)
    case "unloadModel":
      bridge.unload()
      result(nil)
    case "getModelStatus":
      result(bridge.statusText())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func translateNative(text: String, sourceLanguage: String, targetLanguage: String, result: @escaping FlutterResult) {
    if !bridge.isLoaded {
      result(FlutterError(code: "translate_failed", message: "模型未加载", details: nil))
      return
    }
    bridge.translateText(text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { translated, error in
      if let error = error {
        result(FlutterError(code: "translate_failed", message: error.localizedDescription, details: nil))
        return
      }
      result(translated ?? "")
    }
  }

  private func handleBeginTranslation(text: String, sourceLanguage: String, targetLanguage: String, result: @escaping FlutterResult) {
    if !bridge.isLoaded {
      result(FlutterError(code: "translate_failed", message: "模型未加载", details: nil))
      return
    }
    var error: NSString?
    if bridge.beginTranslation(text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, error: &error) {
      result(nil)
    } else {
      result(FlutterError(code: "translate_failed", message: error as String? ?? "翻译启动失败", details: nil))
    }
  }

  private func handleGenerateNextToken(result: @escaping FlutterResult) {
    let piece = bridge.generateNextToken()
    result(piece)
  }

  private func pickModelFile(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = false
      if #available(macOS 11.0, *) {
        panel.allowedContentTypes = [UTType(filenameExtension: "gguf")!]
      } else {
        panel.allowedFileTypes = ["gguf"]
      }
      panel.begin { response in
        if response == .OK {
          result(panel.url?.path)
          return
        }
        result(nil)
      }
    }
  }

  private func importModelFile(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = false
      if #available(macOS 11.0, *) {
        panel.allowedContentTypes = [UTType(filenameExtension: "gguf")!]
      } else {
        panel.allowedFileTypes = ["gguf"]
      }
      panel.begin { response in
        guard response == .OK, let sourceURL = panel.url else {
          result(nil)
          return
        }
        do {
          let importedURL = try self.copyModelToAppSupport(sourceURL)
          result(importedURL.path)
        } catch {
          result(FlutterError(code: "import_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func copyModelToAppSupport(_ sourceURL: URL) throws -> URL {
    guard sourceURL.pathExtension.lowercased() == "gguf" else {
      throw NSError(domain: "Translator", code: 10, userInfo: [NSLocalizedDescriptionKey: "请选择 GGUF 模型文件。"])
    }

    let handle = try FileHandle(forReadingFrom: sourceURL)
    defer { handle.closeFile() }
    let magic = handle.readData(ofLength: 4)
    guard magic == Data([0x47, 0x47, 0x55, 0x46]) else {
      throw NSError(domain: "Translator", code: 11, userInfo: [NSLocalizedDescriptionKey: "文件不是有效的 GGUF 模型。"])
    }

    let modelsURL = try modelsDirectoryURL()

    let destinationURL = modelsURL.appendingPathComponent(sourceURL.lastPathComponent)
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      let sourceSize = try sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
      let destinationSize = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
      if sourceSize == destinationSize {
        return destinationURL
      }
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
  }

  private func findLocalModel(result: @escaping FlutterResult) {
    do {
      let modelsDir = try modelsDirectoryURL()
      let files = try FileManager.default.contentsOfDirectory(
        at: modelsDir,
        includingPropertiesForKeys: [.fileSizeKey],
        options: .skipsHiddenFiles
      )
      let ggufFiles = files.filter { $0.pathExtension.lowercased() == "gguf" }
      if let first = ggufFiles.first {
        let name = first.lastPathComponent
        result(["path": first.path, "name": name])
      } else {
        result(nil)
      }
    } catch {
      result(nil)
    }
  }

  private func listLocalModels(result: @escaping FlutterResult) {
    do {
      let modelsDir = try modelsDirectoryURL()
      let files = try FileManager.default.contentsOfDirectory(
        at: modelsDir,
        includingPropertiesForKeys: [.fileSizeKey],
        options: .skipsHiddenFiles
      )
      let models = files
        .filter { $0.pathExtension.lowercased() == "gguf" }
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        .map { url -> [String: Any] in
          let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
          return [
            "path": url.path,
            "name": url.lastPathComponent,
            "sizeBytes": size
          ]
        }
      result(models)
    } catch {
      result([])
    }
  }

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

  private func downloadDefaultModel(result: @escaping FlutterResult) {
    do {
      let destinationURL = try defaultModelDestinationURL()
      if FileManager.default.fileExists(atPath: destinationURL.path),
         isValidGGUF(at: destinationURL, minimumBytes: minimumModelBytes) {
        updateDownloadStatus(
          state: "completed",
          receivedBytes: 0,
          totalBytes: 0,
          message: "模型已存在",
          path: destinationURL.path
        )
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
    updateDownloadStatus(
      state: "downloading",
      receivedBytes: 0,
      totalBytes: 0,
      message: "正在连接 ModelScope",
      path: nil
    )
    let task = downloadSession.downloadTask(with: defaultModelURL)
    downloadTask = task
    task.resume()
  }

  private func cancelModelDownload() {
    downloadTask?.cancel()
    downloadTask = nil
    updateDownloadStatus(
      state: "cancelled",
      receivedBytes: 0,
      totalBytes: 0,
      message: "下载已取消。",
      path: nil
    )
    pendingDownloadResult?(nil)
    pendingDownloadResult = nil
  }

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
}

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
