import 'dart:async';

import 'package:ai_offline_translator/features/translator/translator_controller.dart';
import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:ai_offline_translator/features/translator/translator_state.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedTranslatorService implements TranslatorService {
  DelayedTranslatorService(this._completer);

  final Completer<String> _completer;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {}

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return _completer.future;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> getModelStatus() async => 'Local model ready';
}

class ThrowingTranslatorService implements TranslatorService {
  const ThrowingTranslatorService();

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {}

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    throw StateError('native bridge unavailable');
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> getModelStatus() async => 'Native bridge not connected';
}

void main() {
  test('initial state is idle with default languages', () {
    final controller = TranslatorController(service: const MockTranslatorService());

    expect(controller.state.status, TranslatorStatus.idle);
    expect(controller.state.sourceLanguage, 'English');
    expect(controller.state.targetLanguage, 'Chinese');
  });

  test('empty input is rejected without calling translation', () async {
    final controller = TranslatorController(service: const MockTranslatorService());

    await controller.translate('   ');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, 'Enter text to translate.');
  });

  test('successful translation updates output', () async {
    final controller = TranslatorController(service: const MockTranslatorService());

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.completed);
    expect(controller.state.inputText, 'Hello');
    expect(controller.state.outputText, '你好');
  });

  test('service errors are surfaced', () async {
    final controller = TranslatorController(service: const ThrowingTranslatorService());

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, 'native bridge unavailable');
  });

  test('cancel sets cancelled state', () async {
    final controller = TranslatorController(service: const MockTranslatorService());

    await controller.cancel();

    expect(controller.state.status, TranslatorStatus.cancelled);
  });

  test('cancel prevents in-flight translation from overwriting state', () async {
    final completer = Completer<String>();
    final controller = TranslatorController(
      service: DelayedTranslatorService(completer),
    );

    controller.updateInput('Hello');
    final translation = controller.translate();
    await controller.cancel();
    completer.complete('你好');
    await translation;

    expect(controller.state.status, TranslatorStatus.cancelled);
    expect(controller.state.outputText, isEmpty);
  });
}
