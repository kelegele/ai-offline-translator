import 'dart:async';

import 'package:ai_offline_translator/features/translator/model_selection_state.dart';
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
  Future<String> getModelStatus() async => '本地模型已就绪';
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
    throw StateError('原生翻译桥接不可用');
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> getModelStatus() async => '原生桥接未连接';
}

class RecordingTranslatorService implements TranslatorService {
  RecordingTranslatorService({this.translateResult = '你好'});

  final String translateResult;
  String? loadedPath;
  int cancelCount = 0;
  String modelStatus = '未加载模型';

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {
    loadedPath = path;
    modelStatus = '本地模型已就绪';
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    return translateResult;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
  }

  @override
  Future<void> unloadModel() async {
    loadedPath = null;
    modelStatus = '未加载模型';
  }

  @override
  Future<String> getModelStatus() async => modelStatus;
}

void main() {
  test('initial state is idle with default languages', () {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );

    expect(controller.state.status, TranslatorStatus.idle);
    expect(controller.state.sourceLanguage, '英语');
    expect(controller.state.targetLanguage, '中文');
  });

  test('empty input is rejected without calling translation', () async {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );

    await controller.translate('   ');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, '请输入要翻译的内容。');
  });

  test('successful translation updates output', () async {
    final service = RecordingTranslatorService();
    final controller = TranslatorController(service: service);
    controller.selectModel('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');
    await controller.loadSelectedModel();

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.completed);
    expect(controller.state.inputText, 'Hello');
    expect(controller.state.outputText, '你好');
  });

  test('service errors are surfaced', () async {
    final controller = TranslatorController(
      service: const ThrowingTranslatorService(),
    );
    controller.selectModel('/tmp/demo.gguf');
    await controller.loadSelectedModel();

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, '原生翻译桥接不可用');
  });

  test('cancel sets cancelled state', () async {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );

    await controller.cancel();

    expect(controller.state.status, TranslatorStatus.cancelled);
  });

  test(
    'cancel prevents in-flight translation from overwriting state',
    () async {
      final completer = Completer<String>();
      final service = DelayedTranslatorService(completer);
      final controller = TranslatorController(service: service);
      controller.selectModel('/tmp/demo.gguf');
      await controller.loadSelectedModel();
      controller.updateInput('Hello');
      final translation = controller.translate();
      await controller.cancel();
      completer.complete('你好');
      await translation;

      expect(controller.state.status, TranslatorStatus.cancelled);
      expect(controller.state.outputText, isEmpty);
    },
  );

  test('selecting model stores path and file name', () {
    final controller = TranslatorController(
      service: RecordingTranslatorService(),
    );

    controller.selectModel('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');

    expect(
      controller.state.modelState.selectedPath,
      '/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf',
    );
    expect(
      controller.state.modelState.displayName,
      'Hy-MT1.5-1.8B-STQ1_0.gguf',
    );
  });

  test('loadModel updates model state to ready', () async {
    final service = RecordingTranslatorService();
    final controller = TranslatorController(service: service);
    controller.selectModel('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');

    await controller.loadSelectedModel();

    expect(service.loadedPath, '/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');
    expect(controller.state.modelState.status, ModelLifecycleStatus.ready);
    expect(controller.state.runtimeStatus, '本地模型已就绪');
  });

  test('translate fails when no model is ready', () async {
    final controller = TranslatorController(
      service: RecordingTranslatorService(),
    );
    controller.updateInput('Hello');

    await controller.translate();

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, '请先加载模型。');
  });
}
