import 'dart:async';

import 'package:ai_offline_translator/features/translator/local_model_info.dart';
import 'package:ai_offline_translator/features/translator/model_download_state.dart';
import 'package:ai_offline_translator/features/translator/model_selection_state.dart';
import 'package:ai_offline_translator/features/translator/supported_model_info.dart';
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
  int unloadCount = 0;
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
    cancelCount += 1;
  }

  @override
  Future<void> unloadModel() async {
    unloadCount += 1;
    loadedPath = null;
    modelStatus = '未加载模型';
  }

  @override
  Future<String> getModelStatus() async => modelStatus;
}

class StreamingTranslatorService implements TranslatorService {
  final StreamController<String> chunks = StreamController<String>();
  final Completer<void> completion = Completer<void>();
  String? loadedPath;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) async {
    loadedPath = path;
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    await completion.future;
    return '你好';
  }

  @override
  Stream<String> translateStream({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return chunks.stream;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> getModelStatus() async => '本地模型已就绪';
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

  test('streaming translation updates output before completion', () async {
    final service = StreamingTranslatorService();
    final controller = TranslatorController(service: service);
    controller.selectModel('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');
    await controller.loadSelectedModel();

    final translation = controller.translate('Hello');
    service.chunks.add('你');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.state.status, TranslatorStatus.translating);
    expect(controller.state.outputText, '你');

    service.chunks.add('好');
    await service.chunks.close();
    service.completion.complete();
    await translation;

    expect(controller.state.status, TranslatorStatus.completed);
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

  test(
    'loadModel asks user to import or download when no model is selected',
    () async {
      final controller = TranslatorController(
        service: RecordingTranslatorService(),
      );

      await controller.loadSelectedModel();

      expect(controller.state.status, TranslatorStatus.error);
      expect(controller.state.errorMessage, '请先导入或下载 GGUF 模型。');
    },
  );

  test('download default model selects returned path', () {
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
    expect(controller.state.modelState.errorMessage, '模型下载失败，请检查网络后重试。');
  });

  test('refreshLocalModels selects preferred downloaded model', () {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );
    const first = LocalModelInfo(
      path: '/app/models/a.gguf',
      name: 'a.gguf',
      sizeBytes: 10,
    );
    const second = LocalModelInfo(
      path: '/app/models/Hy-MT2-1.8B-1.25Bit.gguf',
      name: 'Hy-MT2-1.8B-1.25Bit.gguf',
      sizeBytes: 461373440,
    );

    controller.refreshLocalModels(
      [first, second],
      preferredPath: second.path,
    );

    expect(controller.state.modelState.availableModels, [second, first]);
    expect(controller.state.modelState.selectedPath, second.path);
    expect(controller.state.modelState.displayName, second.name);
  });

  test('selectLocalModel updates selected model without marking it loaded', () {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );
    const model = LocalModelInfo(
      path: '/app/models/Hy-MT2-1.8B-1.25Bit.gguf',
      name: 'Hy-MT2-1.8B-1.25Bit.gguf',
      sizeBytes: 461373440,
    );

    controller.selectLocalModel(model);

    expect(controller.state.modelState.selectedPath, model.path);
    expect(controller.state.modelState.loadedPath, isNull);
    expect(controller.state.modelState.status, ModelLifecycleStatus.selected);
  });

  test('loading another selected model unloads previous model first', () async {
    final service = RecordingTranslatorService();
    final controller = TranslatorController(service: service);
    const first = LocalModelInfo(
      path: '/app/models/a.gguf',
      name: 'a.gguf',
      sizeBytes: 10,
    );
    const second = LocalModelInfo(
      path: '/app/models/b.gguf',
      name: 'b.gguf',
      sizeBytes: 20,
    );

    controller.selectLocalModel(first);
    await controller.loadSelectedModel();
    controller.selectLocalModel(second);
    await controller.loadSelectedModel();

    expect(service.cancelCount, 0);
    expect(service.unloadCount, 1);
    expect(service.loadedPath, second.path);
    expect(controller.state.modelState.loadedPath, second.path);
  });

  test('beginModelDownload tracks supported model id', () {
    final controller = TranslatorController(
      service: const MockTranslatorService(),
    );
    final model = supportedTranslatorModels.first;

    controller.beginModelDownload(modelId: model.id);

    expect(controller.state.modelState.downloadingModelId, model.id);
    expect(
      controller.state.modelDownloadState.status,
      ModelDownloadStatus.downloading,
    );
  });
}
