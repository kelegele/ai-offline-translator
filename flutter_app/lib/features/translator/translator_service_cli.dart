import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'prompt_builder.dart';
import 'translator_service.dart';

class LlamaCliTranslatorService implements TranslatorService {
  LlamaCliTranslatorService({
    this.executablePath = '../third_party/llama.cpp/build/bin/llama-completion',
    Duration timeout = const Duration(seconds: 60),
  }) : _timeout = timeout;

  final String executablePath;
  final Duration _timeout;

  String? _modelPath;
  int _nCtx = 256;
  int _nThreads = 2;
  Process? _activeProcess;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {
    final model = File(path);
    final executable = File(executablePath);
    if (!await model.exists()) {
      throw StateError('模型文件不存在：$path');
    }
    if (!await executable.exists()) {
      throw StateError('llama.cpp 可执行文件不存在：$executablePath');
    }

    _modelPath = path;
    _nCtx = nCtx;
    _nThreads = nThreads;
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final modelPath = _modelPath;
    if (modelPath == null) {
      throw StateError('请先加载模型。');
    }

    final prompt = PromptBuilder.build(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    final process = await Process.start(executablePath, [
      '--model',
      modelPath,
      '-p',
      prompt,
      '--jinja',
      '-ngl',
      '0',
      '-n',
      '128',
      '-c',
      _nCtx.toString(),
      '-t',
      _nThreads.toString(),
      '-tb',
      '1',
      '--no-warmup',
      '-st',
    ], runInShell: false);

    _activeProcess = process;
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();

    Timer? killTimer;
    try {
      killTimer = Timer(_timeout, () {
        process.kill(ProcessSignal.sigkill);
      });
      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (exitCode != 0) {
        throw StateError(_compactError(stderrBuffer.toString(), exitCode));
      }
      return _cleanOutput(stdoutBuffer.toString(), text);
    } finally {
      killTimer?.cancel();
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  @override
  Stream<String> translateStream({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async* {
    yield await translate(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  @override
  Future<void> cancel() async {
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
  }

  @override
  Future<void> unloadModel() async {
    await cancel();
    _modelPath = null;
  }

  @override
  Future<String> getModelStatus() async {
    if (_modelPath == null) {
      return '未加载模型';
    }
    return '本地模型已就绪（CPU 安全模式）';
  }

  String _cleanOutput(String rawOutput, String sourceText) {
    var output = rawOutput.trim();
    output = output.replaceAll('[end of text]', '').trim();
    final doubleNewline = output.lastIndexOf('\n\n');
    if (doubleNewline != -1) {
      output = output.substring(doubleNewline + 2).trim();
    }
    if (output.startsWith(sourceText)) {
      output = output.substring(sourceText.length).trim();
    }
    return output.isEmpty ? rawOutput.trim() : output;
  }

  String _compactError(String rawError, int exitCode) {
    final lines = rawError
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .join('\n');
    return lines.isEmpty ? 'llama.cpp 推理失败，退出码：$exitCode' : lines;
  }
}
