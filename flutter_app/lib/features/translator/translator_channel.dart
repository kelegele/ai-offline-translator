import 'package:flutter/services.dart';

class TranslatorChannel {
  const TranslatorChannel({
    MethodChannel channel = const MethodChannel(
      'ai_offline_translator/translator',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  Future<String?> pickModelFile() {
    return _channel.invokeMethod<String>('pickModelFile');
  }

  Future<String?> importModelFile() {
    return _channel.invokeMethod<String>('importModelFile');
  }

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

  Future<Map<String, dynamic>?> findLocalModel() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'findLocalModel',
    );
    return result;
  }

  Future<Map<String, Object?>> getModelDownloadStatus() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getModelDownloadStatus',
    );
    return result ?? const {};
  }

  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {
    await _channel.invokeMethod<void>('loadModel', {
      'path': path,
      'nCtx': nCtx,
      'nThreads': nThreads,
    });
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required String modelPath,
  }) async {
    final result = await _channel.invokeMethod<String>('translate', {
      'text': text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'modelPath': modelPath,
    });
    return result ?? '';
  }

  Stream<String> translateStream({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required String modelPath,
  }) async* {
    await _channel.invokeMethod<void>('beginTranslation', {
      'text': text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'modelPath': modelPath,
    });

    while (true) {
      final chunk = await _channel.invokeMethod<String>('generateNextToken');
      if (chunk == null) break;
      if (chunk.isNotEmpty) yield chunk;
    }
  }

  Future<void> cancel() async {
    await _channel.invokeMethod<void>('cancel');
  }

  Future<void> unloadModel() async {
    await _channel.invokeMethod<void>('unloadModel');
  }

  Future<String> getModelStatus() async {
    return await _channel.invokeMethod<String>('getModelStatus') ?? '原生桥接未连接';
  }
}
