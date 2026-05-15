import Foundation
import FlutterMacOS

final class TranslatorChannelHandler: NSObject {
  private let channelName = "ai_offline_translator/translator"
  private let service = MacOSLlamaService()

  func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickModelFile":
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
    case "loadModel":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let nCtx = args["nCtx"] as? Int,
            let nThreads = args["nThreads"] as? Int else {
        result(FlutterError(code: "bad_args", message: "缺少模型加载参数", details: nil))
        return
      }

      service.loadModel(path: path, nCtx: nCtx, nThreads: nThreads) { error in
        if let error {
          result(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(nil)
      }
    case "translate":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String,
            let sourceLanguage = args["sourceLanguage"] as? String,
            let targetLanguage = args["targetLanguage"] as? String else {
        result(FlutterError(code: "bad_args", message: "缺少翻译参数", details: nil))
        return
      }

      service.translate(
        text: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage
      ) { translation, error in
        if let error {
          result(FlutterError(code: "translate_failed", message: error.localizedDescription, details: nil))
          return
        }
        result(translation ?? "")
      }
    case "cancel":
      service.cancel()
      result(nil)
    case "unloadModel":
      service.unloadModel()
      result(nil)
    case "getModelStatus":
      result(service.modelStatus)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class MacOSLlamaService {
  private var modelPath: String?
  private var nCtx: Int = 256
  private var nThreads: Int = 2
  private var activeProcess: Process?

  var modelStatus: String {
    if modelPath == nil {
      return "未加载模型"
    }
    return "本地模型已就绪（CPU 安全模式）"
  }

  func loadModel(path: String, nCtx: Int, nThreads: Int, completion: @escaping (NSError?) -> Void) {
    let absoluteModelPath = resolvedModelPath(path)
    let binaryPath = resolvedBinaryPath()
    NSLog("[Translator] loadModel inputPath=\(path)")
    NSLog("[Translator] currentDirectory=\(FileManager.default.currentDirectoryPath)")
    NSLog("[Translator] resolvedModelPath=\(absoluteModelPath)")
    NSLog("[Translator] resolvedBinaryPath=\(binaryPath)")

    guard FileManager.default.fileExists(atPath: absoluteModelPath) else {
      completion(NSError(domain: "Translator", code: 1, userInfo: [NSLocalizedDescriptionKey: "模型文件不存在：\(absoluteModelPath)"]))
      return
    }

    guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
      completion(NSError(domain: "Translator", code: 2, userInfo: [NSLocalizedDescriptionKey: "llama.cpp 可执行文件不存在：\(binaryPath)"]))
      return
    }

    self.modelPath = absoluteModelPath
    self.nCtx = nCtx
    self.nThreads = nThreads
    completion(nil)
  }

  func translate(text: String, sourceLanguage: String, targetLanguage: String, completion: @escaping (String?, NSError?) -> Void) {
    guard let modelPath else {
      completion(nil, NSError(domain: "Translator", code: 3, userInfo: [NSLocalizedDescriptionKey: "请先加载模型。"]))
      return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: resolvedBinaryPath())
    process.arguments = [
      "--model", modelPath,
      "-p", prompt(for: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage),
      "--jinja",
      "-ngl", "0",
      "-n", "128",
      "-c", String(nCtx),
      "-t", String(nThreads),
      "-tb", "1",
      "--no-warmup",
      "-st"
    ]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    activeProcess = process

    do {
      try process.run()
    } catch {
      activeProcess = nil
      completion(nil, error as NSError)
      return
    }

    DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak process] in
      guard let process, process.isRunning else { return }
      process.terminate()
    }

    process.terminationHandler = { [weak self] runningProcess in
      let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
      let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
      let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
      let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
      self?.activeProcess = nil

      DispatchQueue.main.async {
        guard runningProcess.terminationStatus == 0 else {
          let message = self?.compactError(stderrText, exitCode: Int(runningProcess.terminationStatus)) ?? "llama.cpp 推理失败"
          completion(nil, NSError(domain: "Translator", code: 4, userInfo: [NSLocalizedDescriptionKey: message]))
          return
        }
        completion(self?.cleanOutput(stdoutText, sourceText: text) ?? stdoutText.trimmingCharacters(in: .whitespacesAndNewlines), nil)
      }
    }
  }

  func cancel() {
    activeProcess?.terminate()
    activeProcess = nil
  }

  func unloadModel() {
    cancel()
    modelPath = nil
  }

  private func prompt(for text: String, sourceLanguage: String, targetLanguage: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if sourceLanguage == "中文" {
      return "请将以下内容翻译为\(targetLanguage)：\n\n\(trimmed)"
    }
    return "Please translate to \(targetLanguage), without additional explanation:\n\n\(trimmed)"
  }

  private func cleanOutput(_ rawOutput: String, sourceText: String) -> String {
    var output = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    output = output.replacingOccurrences(of: "[end of text]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    if output.hasPrefix(sourceText) {
      output = String(output.dropFirst(sourceText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return output.isEmpty ? rawOutput.trimmingCharacters(in: .whitespacesAndNewlines) : output
  }

  private func compactError(_ rawError: String, exitCode: Int) -> String {
    let lines = rawError
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .prefix(6)
    if lines.isEmpty {
      return "llama.cpp 推理失败，退出码：\(exitCode)"
    }
    return lines.joined(separator: "\n")
  }

  private func resolvedBinaryPath() -> String {
    return repositoryRoot()
      .appendingPathComponent("third_party/llama.cpp/build/bin/llama-completion")
      .path
  }

  private func resolvedModelPath(_ path: String) -> String {
    if path.hasPrefix("/") {
      return path
    }
    return repositoryRoot().appendingPathComponent(path).path
  }

  private func repositoryRoot() -> URL {
    let sourceFile = URL(fileURLWithPath: #filePath)
    return sourceFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
