import 'dart:async';
import 'package:flutter/foundation.dart';

import 'model_download_state.dart';
import 'model_selection_state.dart';
import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorController extends ChangeNotifier {
  TranslatorController({required TranslatorService service})
    : _service = service;

  final TranslatorService _service;

  TranslatorState _state = const TranslatorState();
  int _requestToken = 0;

  TranslatorState get state => _state;

  void updateInput(String text) {
    _state = _state.copyWith(
      inputText: text,
      status: text.trim().isEmpty
          ? TranslatorStatus.idle
          : TranslatorStatus.ready,
      clearError: true,
    );
    notifyListeners();
  }

  void updateSourceLanguage(String language) {
    _state = _state.copyWith(sourceLanguage: language, clearError: true);
    notifyListeners();
  }

  void updateTargetLanguage(String language) {
    _state = _state.copyWith(targetLanguage: language, clearError: true);
    notifyListeners();
  }

  void selectModel(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(
        runtimeStatus: '未加载模型',
        modelState: const ModelSelectionState(),
        clearError: true,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      runtimeStatus: '已选择模型，等待加载',
      modelState: ModelSelectionState(
        status: ModelLifecycleStatus.selected,
        selectedPath: trimmed,
        displayName: trimmed.split('/').last,
      ),
      clearError: true,
    );
    notifyListeners();
  }

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

  Future<void> loadSelectedModel() async {
    final path = _state.modelState.selectedPath;
    if (path == null || path.trim().isEmpty) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        runtimeStatus: '未选择模型',
        modelState: _state.modelState.copyWith(
          status: ModelLifecycleStatus.failed,
          errorMessage: '请先导入或下载 GGUF 模型。',
        ),
        errorMessage: '请先导入或下载 GGUF 模型。',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      runtimeStatus: '正在加载模型',
      modelState: _state.modelState.copyWith(
        status: ModelLifecycleStatus.loading,
        clearError: true,
      ),
      clearError: true,
    );
    notifyListeners();

    try {
      await _service.loadModel(path: path, nCtx: 256, nThreads: 2);
      final runtimeStatus = await _service.getModelStatus();
      _state = _state.copyWith(
        status: _state.inputText.trim().isEmpty
            ? TranslatorStatus.idle
            : TranslatorStatus.ready,
        runtimeStatus: runtimeStatus,
        modelState: _state.modelState.copyWith(
          status: ModelLifecycleStatus.ready,
          clearError: true,
        ),
        clearError: true,
      );
    } on Object catch (error) {
      final message = messageFor(error);
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        runtimeStatus: '模型加载失败',
        modelState: _state.modelState.copyWith(
          status: ModelLifecycleStatus.failed,
          errorMessage: message,
        ),
        errorMessage: message,
      );
    }
    notifyListeners();
  }

  Future<void> translate([String? text]) async {
    final trimmed = (text ?? _state.inputText).trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        inputText: text,
        errorMessage: '请输入要翻译的内容。',
      );
      notifyListeners();
      return;
    }

    if (!_state.modelState.isReady) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        inputText: trimmed,
        errorMessage: '请先加载模型。',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: TranslatorStatus.translating,
      inputText: trimmed,
      outputText: '',
      clearError: true,
    );
    notifyListeners();

    final requestToken = ++_requestToken;

    try {
      final outputBuffer = StringBuffer();
      Timer? flushTimer;

      void flushOutput() {
        flushTimer?.cancel();
        flushTimer = null;
        if (requestToken != _requestToken) return;
        _state = _state.copyWith(outputText: outputBuffer.toString());
        notifyListeners();
      }

      void scheduleFlush() {
        if (flushTimer != null) return;
        flushTimer = Timer(const Duration(milliseconds: 80), flushOutput);
      }

      await for (final chunk in _service.translateStream(
        text: trimmed,
        sourceLanguage: _state.sourceLanguage,
        targetLanguage: _state.targetLanguage,
      )) {
        if (requestToken != _requestToken) {
          flushTimer?.cancel();
          return;
        }
        outputBuffer.write(chunk);
        scheduleFlush();
      }
      flushOutput();

      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.completed,
        outputText: outputBuffer.toString(),
        clearError: true,
      );
    } on Object catch (error) {
      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        errorMessage: messageFor(error),
        clearError: true,
      );
    }
    notifyListeners();
  }


  Future<void> cancel() async {
    _requestToken++;
    await _service.cancel();
    _state = _state.copyWith(status: TranslatorStatus.cancelled);
    notifyListeners();
  }

  Future<void> unloadModel() async {
    await _service.unloadModel();
    _state = _state.copyWith(
      modelState: const ModelSelectionState(),
      runtimeStatus: "未加载模型",
    );
    notifyListeners();
  }

  String messageFor(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is Exception) {
      return error.toString();
    }
    return error.toString();
  }
}
