import Foundation
import FlutterMacOS

final class TranslatorChannelHandler: NSObject {
  private let channelName = "ai_offline_translator/translator"
  private let bridge = TranslatorBridge()

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

  private func pickModelFile(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = ["gguf"]
    panel.begin { response in
      if response == .OK {
        result(panel.url?.path)
        return
      }
      result(nil)
    }
  }

  private func importModelFile(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = ["gguf"]
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
}
