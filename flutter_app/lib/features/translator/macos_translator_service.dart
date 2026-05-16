import 'package:flutter/foundation.dart';

import 'translator_channel.dart';
import 'android_translator_service.dart';
import 'translator_service.dart';

class MacosTranslatorService implements TranslatorService {
  MacosTranslatorService({TranslatorChannel? channel})
    : _channel = channel ?? const TranslatorChannel();

  final TranslatorChannel _channel;
  String? _modelPath;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
    _modelPath = path;
    return _channel.loadModel(path: path, nCtx: nCtx, nThreads: nThreads);
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return _channel.translate(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      modelPath: _modelPath ?? '',
    );
  }

  @override
  Stream<String> translateStream({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return _channel.translateStream(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      modelPath: _modelPath ?? '',
    );
  }

  @override
  Future<void> cancel() {
    return _channel.cancel();
  }

  @override
  Future<void> unloadModel() {
    return _channel.unloadModel();
  }

  @override
  Future<String> getModelStatus() {
    return _channel.getModelStatus();
  }
}

TranslatorService createDefaultTranslatorService() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidTranslatorService();
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return MacosTranslatorService();
  }
  return const MockTranslatorService();
}
