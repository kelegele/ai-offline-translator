# macOS Real Inference Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter mock translation path with a real macOS-backed offline translation flow that loads a local GGUF model file, calls a native bridge on macOS, and returns real translation output through the existing translator workspace.

**Architecture:** Keep Flutter responsible for UI, state, and model-selection flow. Introduce a real Dart service backed by a macOS `MethodChannel` implementation, and add a thin Apple-native bridge that calls a dedicated `translator_engine` layer linked against the pinned `llama.cpp` runtime. The first slice supports one manually selected local model file and one translation flow with cancellation.

**Tech Stack:** Flutter 3.35.5, Dart 3.9.2, Flutter macOS host app, `MethodChannel`, Swift, Objective-C++, C++, `llama.cpp` from `third_party/llama.cpp`, GGUF file loading from local filesystem.

---

## File Structure

- Modify: `flutter_app/lib/features/translator/translator_state.dart`
- Modify: `flutter_app/lib/features/translator/translator_controller.dart`
- Modify: `flutter_app/lib/features/translator/translator_service.dart`
- Modify: `flutter_app/lib/features/translator/translator_channel.dart`
- Modify: `flutter_app/lib/features/translator/translator_page.dart`
- Create: `flutter_app/lib/features/translator/model_selection_state.dart`
- Create: `flutter_app/lib/features/translator/prompt_builder.dart`
- Create: `flutter_app/lib/features/translator/macos_translator_service.dart`
- Create: `flutter_app/test/features/translator/prompt_builder_test.dart`
- Modify: `flutter_app/test/features/translator/translator_controller_test.dart`
- Modify: `flutter_app/test/widget_test.dart`
- Create: `flutter_app/macos/Runner/TranslatorChannelHandler.swift`
- Create: `flutter_app/macos/Runner/Native/translator_bridge.mm`
- Create: `flutter_app/macos/Runner/Native/translator_engine.hpp`
- Create: `flutter_app/macos/Runner/Native/translator_engine.cpp`
- Modify: `flutter_app/macos/Runner.xcodeproj/project.pbxproj`
- Modify: `flutter_app/macos/Runner/AppDelegate.swift`
- Modify: `README.md`
- Optional modify: `docs/flutter_mobile_architecture.md`

## Task 1: Add Prompt Builder and Model Selection State

**Files:**
- Create: `flutter_app/lib/features/translator/prompt_builder.dart`
- Create: `flutter_app/lib/features/translator/model_selection_state.dart`
- Create: `flutter_app/test/features/translator/prompt_builder_test.dart`

- [ ] **Step 1: Write failing prompt-builder tests**

Create `flutter_app/test/features/translator/prompt_builder_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/features/translator/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds Chinese prompt when source language is Chinese', () {
    final prompt = PromptBuilder.build(
      text: '你好，世界',
      sourceLanguage: '中文',
      targetLanguage: '英语',
    );

    expect(prompt, '请将以下内容翻译为英语：\n\n你好，世界');
  });

  test('builds English prompt when source language is not Chinese', () {
    final prompt = PromptBuilder.build(
      text: 'Hello world',
      sourceLanguage: '英语',
      targetLanguage: '中文',
    );

    expect(
      prompt,
      'Please translate to 中文:\n\nHello world',
    );
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/prompt_builder_test.dart
```

Expected: FAIL because `prompt_builder.dart` does not exist.

- [ ] **Step 2: Add prompt builder implementation**

Create `flutter_app/lib/features/translator/prompt_builder.dart` exactly as:

```dart
class PromptBuilder {
  const PromptBuilder._();

  static String build({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    final trimmed = text.trim();
    if (sourceLanguage == '中文') {
      return '请将以下内容翻译为$targetLanguage：\n\n$trimmed';
    }

    return 'Please translate to $targetLanguage:\n\n$trimmed';
  }
}
```

Run the prompt-builder test again. Expected: PASS.

- [ ] **Step 3: Add model-selection state**

Create `flutter_app/lib/features/translator/model_selection_state.dart` exactly as:

```dart
enum ModelLifecycleStatus {
  noneSelected,
  selected,
  loading,
  ready,
  unloading,
  failed,
}

class ModelSelectionState {
  const ModelSelectionState({
    this.status = ModelLifecycleStatus.noneSelected,
    this.selectedPath,
    this.displayName,
    this.errorMessage,
  });

  final ModelLifecycleStatus status;
  final String? selectedPath;
  final String? displayName;
  final String? errorMessage;

  bool get hasSelectedModel => selectedPath != null && selectedPath!.isNotEmpty;

  ModelSelectionState copyWith({
    ModelLifecycleStatus? status,
    String? selectedPath,
    String? displayName,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ModelSelectionState(
      status: status ?? this.status,
      selectedPath: selectedPath ?? this.selectedPath,
      displayName: displayName ?? this.displayName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
```

- [ ] **Step 4: Run analyzer and focused tests**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/prompt_builder_test.dart
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add flutter_app/lib/features/translator/prompt_builder.dart flutter_app/lib/features/translator/model_selection_state.dart flutter_app/test/features/translator/prompt_builder_test.dart
git commit -m "Add prompt and model state"
```

Expected: commit succeeds.

## Task 2: Expand Dart Service and Controller for Real Model Lifecycle

**Files:**
- Modify: `flutter_app/lib/features/translator/translator_state.dart`
- Modify: `flutter_app/lib/features/translator/translator_service.dart`
- Create: `flutter_app/lib/features/translator/macos_translator_service.dart`
- Modify: `flutter_app/lib/features/translator/translator_controller.dart`
- Modify: `flutter_app/test/features/translator/translator_controller_test.dart`

- [ ] **Step 1: Add failing controller tests for model lifecycle**

Extend `flutter_app/test/features/translator/translator_controller_test.dart` by appending these tests before the final closing brace:

```dart
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

test('selecting model stores path and file name', () {
  final controller = TranslatorController(service: RecordingTranslatorService());

  controller.selectModel('/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');

  expect(controller.state.modelState.selectedPath, '/tmp/Hy-MT1.5-1.8B-STQ1_0.gguf');
  expect(controller.state.modelState.displayName, 'Hy-MT1.5-1.8B-STQ1_0.gguf');
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
  final controller = TranslatorController(service: RecordingTranslatorService());
  controller.updateInput('Hello');

  await controller.translate();

  expect(controller.state.status, TranslatorStatus.error);
  expect(controller.state.errorMessage, '请先加载模型。');
});
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_controller_test.dart
```

Expected: FAIL because controller/state do not yet expose model lifecycle.

- [ ] **Step 2: Extend translator state**

Replace `flutter_app/lib/features/translator/translator_state.dart` exactly as:

```dart
import 'model_selection_state.dart';

enum TranslatorStatus {
  idle,
  ready,
  translating,
  completed,
  cancelled,
  error,
}

class TranslatorState {
  const TranslatorState({
    this.status = TranslatorStatus.idle,
    this.inputText = '',
    this.outputText = '',
    this.sourceLanguage = '英语',
    this.targetLanguage = '中文',
    this.runtimeStatus = '未加载模型',
    this.modelState = const ModelSelectionState(),
    this.errorMessage,
  });

  final TranslatorStatus status;
  final String inputText;
  final String outputText;
  final String sourceLanguage;
  final String targetLanguage;
  final String runtimeStatus;
  final ModelSelectionState modelState;
  final String? errorMessage;

  bool get canTranslate =>
      inputText.trim().isNotEmpty &&
      status != TranslatorStatus.translating &&
      modelState.status == ModelLifecycleStatus.ready;

  TranslatorState copyWith({
    TranslatorStatus? status,
    String? inputText,
    String? outputText,
    String? sourceLanguage,
    String? targetLanguage,
    String? runtimeStatus,
    ModelSelectionState? modelState,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TranslatorState(
      status: status ?? this.status,
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      runtimeStatus: runtimeStatus ?? this.runtimeStatus,
      modelState: modelState ?? this.modelState,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
```

- [ ] **Step 3: Add macOS-backed service wrapper**

Create `flutter_app/lib/features/translator/macos_translator_service.dart` exactly as:

```dart
import 'translator_channel.dart';
import 'translator_service.dart';

class MacosTranslatorService implements TranslatorService {
  MacosTranslatorService({TranslatorChannel? channel})
      : _channel = channel ?? const TranslatorChannel();

  final TranslatorChannel _channel;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
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
    );
  }

  @override
  Future<void> cancel() => _channel.cancel();

  @override
  Future<void> unloadModel() => _channel.unloadModel();

  @override
  Future<String> getModelStatus() => _channel.getModelStatus();
}
```

- [ ] **Step 4: Extend controller for model lifecycle**

Replace `flutter_app/lib/features/translator/translator_controller.dart` exactly as:

```dart
import 'package:flutter/foundation.dart';

import 'model_selection_state.dart';
import 'prompt_builder.dart';
import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorController extends ChangeNotifier {
  TranslatorController({required TranslatorService service}) : _service = service;

  final TranslatorService _service;

  TranslatorState _state = const TranslatorState();
  int _requestToken = 0;

  TranslatorState get state => _state;

  void selectModel(String path) {
    final segments = path.split(RegExp(r'[/\\]'));
    final fileName = segments.isEmpty ? path : segments.last;
    _state = _state.copyWith(
      modelState: _state.modelState.copyWith(
        status: ModelLifecycleStatus.selected,
        selectedPath: path,
        displayName: fileName,
        clearError: true,
      ),
      runtimeStatus: '已选择模型',
      clearError: true,
    );
    notifyListeners();
  }

  Future<void> loadSelectedModel() async {
    final path = _state.modelState.selectedPath;
    if (path == null || path.isEmpty) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        errorMessage: '请先选择模型文件。',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      modelState: _state.modelState.copyWith(
        status: ModelLifecycleStatus.loading,
        clearError: true,
      ),
      runtimeStatus: '正在加载模型',
      clearError: true,
    );
    notifyListeners();

    try {
      await _service.loadModel(path: path, nCtx: 256, nThreads: 2);
      final runtimeStatus = await _service.getModelStatus();
      _state = _state.copyWith(
        modelState: _state.modelState.copyWith(status: ModelLifecycleStatus.ready),
        runtimeStatus: runtimeStatus,
        clearError: true,
      );
    } on Object catch (error) {
      _state = _state.copyWith(
        modelState: _state.modelState.copyWith(
          status: ModelLifecycleStatus.failed,
          errorMessage: error.toString(),
        ),
        status: TranslatorStatus.error,
        runtimeStatus: '模型加载失败',
        errorMessage: error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> unloadModel() async {
    _state = _state.copyWith(
      modelState: _state.modelState.copyWith(status: ModelLifecycleStatus.unloading),
      runtimeStatus: '正在卸载模型',
      clearError: true,
    );
    notifyListeners();

    await _service.unloadModel();

    _state = _state.copyWith(
      modelState: const ModelSelectionState(),
      runtimeStatus: '未加载模型',
      status: TranslatorStatus.idle,
      outputText: '',
      clearError: true,
    );
    notifyListeners();
  }

  void updateInput(String text) {
    _state = _state.copyWith(
      inputText: text,
      status: text.trim().isEmpty ? TranslatorStatus.idle : TranslatorStatus.ready,
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

  Future<void> translate([String? text]) async {
    if (_state.modelState.status != ModelLifecycleStatus.ready) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        errorMessage: '请先加载模型。',
      );
      notifyListeners();
      return;
    }

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

    _state = _state.copyWith(
      status: TranslatorStatus.translating,
      inputText: trimmed,
      outputText: '',
      runtimeStatus: '正在翻译',
      clearError: true,
    );
    notifyListeners();

    final requestToken = ++_requestToken;
    final prompt = PromptBuilder.build(
      text: trimmed,
      sourceLanguage: _state.sourceLanguage,
      targetLanguage: _state.targetLanguage,
    );

    try {
      final output = await _service.translate(
        text: prompt,
        sourceLanguage: _state.sourceLanguage,
        targetLanguage: _state.targetLanguage,
      );
      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.completed,
        outputText: output,
        runtimeStatus: '翻译完成',
        clearError: true,
      );
    } on Object catch (error) {
      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        runtimeStatus: '翻译失败',
        errorMessage: error is StateError ? error.message : error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    _requestToken++;
    await _service.cancel();
    _state = _state.copyWith(
      status: TranslatorStatus.cancelled,
      runtimeStatus: '翻译已取消',
    );
    notifyListeners();
  }

  void clear() {
    _state = _state.copyWith(
      status: TranslatorStatus.idle,
      inputText: '',
      outputText: '',
      runtimeStatus: _state.modelState.status == ModelLifecycleStatus.ready ? '本地模型已就绪' : '未加载模型',
      clearError: true,
    );
    notifyListeners();
  }
}
```

- [ ] **Step 5: Extend service interface**

Replace `flutter_app/lib/features/translator/translator_service.dart` exactly as:

```dart
abstract interface class TranslatorService {
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  });

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });

  Future<void> cancel();

  Future<void> unloadModel();

  Future<String> getModelStatus();
}

class MockTranslatorService implements TranslatorService {
  const MockTranslatorService();

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
  }) async {
    final normalized = text.trim().toLowerCase();
    if (sourceLanguage == '英语' &&
        targetLanguage == '中文' &&
        normalized.contains('hello')) {
      return '你好';
    }

    return text;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> getModelStatus() async {
    return '本地模型已就绪';
  }
}
```

- [ ] **Step 6: Run focused tests and analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_controller_test.dart test/features/translator/prompt_builder_test.dart
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add flutter_app/lib/features/translator/translator_state.dart flutter_app/lib/features/translator/translator_service.dart flutter_app/lib/features/translator/macos_translator_service.dart flutter_app/lib/features/translator/translator_controller.dart flutter_app/test/features/translator/translator_controller_test.dart
git commit -m "Add model lifecycle state"
```

Expected: commit succeeds.

## Task 3: Implement MethodChannel Contract on Dart Side

**Files:**
- Modify: `flutter_app/lib/features/translator/translator_channel.dart`
- Create: `flutter_app/test/features/translator/translator_channel_contract_test.dart`

- [ ] **Step 1: Write channel-contract tests**

Create `flutter_app/test/features/translator/translator_channel_contract_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/features/translator/translator_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ai_offline_translator/translator');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getModelStatus' => '本地模型已就绪',
        'translate' => '你好',
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('loadModel invokes channel with path and params', () async {
    const translatorChannel = TranslatorChannel();

    await translatorChannel.loadModel(
      path: '/tmp/model.gguf',
      nCtx: 256,
      nThreads: 2,
    );

    expect(calls.single.method, 'loadModel');
    expect(calls.single.arguments['path'], '/tmp/model.gguf');
    expect(calls.single.arguments['nCtx'], 256);
    expect(calls.single.arguments['nThreads'], 2);
  });

  test('translate returns native result', () async {
    const translatorChannel = TranslatorChannel();

    final result = await translatorChannel.translate(
      text: 'Please translate to 中文:\n\nHello',
      sourceLanguage: '英语',
      targetLanguage: '中文',
    );

    expect(result, '你好');
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_channel_contract_test.dart
```

Expected: FAIL because the channel still throws `UnimplementedError`.

- [ ] **Step 2: Replace channel implementation**

Replace `flutter_app/lib/features/translator/translator_channel.dart` exactly as:

```dart
import 'package:flutter/services.dart';

class TranslatorChannel {
  const TranslatorChannel();

  static const MethodChannel _channel = MethodChannel('ai_offline_translator/translator');

  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
    return _channel.invokeMethod<void>('loadModel', {
      'path': path,
      'nCtx': nCtx,
      'nThreads': nThreads,
    });
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final result = await _channel.invokeMethod<String>('translate', {
      'text': text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    });

    if (result == null) {
      throw StateError('原生翻译返回空结果');
    }

    return result;
  }

  Future<void> cancel() {
    return _channel.invokeMethod<void>('cancel');
  }

  Future<void> unloadModel() {
    return _channel.invokeMethod<void>('unloadModel');
  }

  Future<String> getModelStatus() async {
    final result = await _channel.invokeMethod<String>('getModelStatus');
    return result ?? '原生桥接未连接';
  }
}
```

- [ ] **Step 3: Run focused test and analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_channel_contract_test.dart
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 4: Commit**

Run:

```bash
git add flutter_app/lib/features/translator/translator_channel.dart flutter_app/test/features/translator/translator_channel_contract_test.dart
git commit -m "Add translator channel contract"
```

Expected: commit succeeds.

## Task 4: Add macOS Native Channel Handler and Bridge Skeleton

**Files:**
- Create: `flutter_app/macos/Runner/TranslatorChannelHandler.swift`
- Create: `flutter_app/macos/Runner/Native/translator_bridge.mm`
- Create: `flutter_app/macos/Runner/Native/translator_engine.hpp`
- Create: `flutter_app/macos/Runner/Native/translator_engine.cpp`
- Modify: `flutter_app/macos/Runner/AppDelegate.swift`
- Modify: `flutter_app/macos/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add failing Dart-side smoke test for missing native methods**

Append this test to `flutter_app/test/features/translator/translator_channel_contract_test.dart` before the final closing brace:

```dart
test('getModelStatus returns mocked native status', () async {
  const translatorChannel = TranslatorChannel();

  final status = await translatorChannel.getModelStatus();

  expect(status, '本地模型已就绪');
});
```

Run the test file to verify the Dart contract still passes before native work.

- [ ] **Step 2: Add native engine header**

Create `flutter_app/macos/Runner/Native/translator_engine.hpp` exactly as:

```cpp
#pragma once

#include <string>

class TranslatorEngine {
 public:
  TranslatorEngine();
  ~TranslatorEngine();

  std::string load_model(const std::string& model_path, int n_ctx, int n_threads);
  std::string translate(const std::string& prompt);
  std::string cancel();
  std::string unload_model();
  std::string get_model_status() const;

 private:
  bool model_loaded_;
  std::string model_path_;
};
```

- [ ] **Step 3: Add temporary native engine implementation**

Create `flutter_app/macos/Runner/Native/translator_engine.cpp` exactly as:

```cpp
#include "translator_engine.hpp"

TranslatorEngine::TranslatorEngine() : model_loaded_(false) {}

TranslatorEngine::~TranslatorEngine() = default;

std::string TranslatorEngine::load_model(const std::string& model_path, int, int) {
  model_path_ = model_path;
  model_loaded_ = !model_path.empty();
  return model_loaded_ ? "本地模型已就绪" : "模型加载失败";
}

std::string TranslatorEngine::translate(const std::string& prompt) {
  if (!model_loaded_) {
    return "未加载模型";
  }

  if (prompt.find("Hello") != std::string::npos || prompt.find("hello") != std::string::npos) {
    return "你好";
  }

  return prompt;
}

std::string TranslatorEngine::cancel() {
  return "翻译已取消";
}

std::string TranslatorEngine::unload_model() {
  model_loaded_ = false;
  model_path_.clear();
  return "未加载模型";
}

std::string TranslatorEngine::get_model_status() const {
  return model_loaded_ ? "本地模型已就绪" : "未加载模型";
}
```

- [ ] **Step 4: Add Objective-C++ bridge**

Create `flutter_app/macos/Runner/Native/translator_bridge.mm` exactly as:

```objective-c++
#import <Foundation/Foundation.h>

#import "translator_engine.hpp"

@interface TranslatorBridge : NSObject
- (NSString *)loadModelAtPath:(NSString *)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads;
- (NSString *)translate:(NSString *)prompt;
- (NSString *)cancel;
- (NSString *)unloadModel;
- (NSString *)modelStatus;
@end

@implementation TranslatorBridge {
  TranslatorEngine *_engine;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _engine = new TranslatorEngine();
  }
  return self;
}

- (void)dealloc {
  delete _engine;
}

- (NSString *)loadModelAtPath:(NSString *)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads {
  const std::string status = _engine->load_model(path.UTF8String, (int)nCtx, (int)nThreads);
  return [NSString stringWithUTF8String:status.c_str()];
}

- (NSString *)translate:(NSString *)prompt {
  const std::string output = _engine->translate(prompt.UTF8String);
  return [NSString stringWithUTF8String:output.c_str()];
}

- (NSString *)cancel {
  const std::string status = _engine->cancel();
  return [NSString stringWithUTF8String:status.c_str()];
}

- (NSString *)unloadModel {
  const std::string status = _engine->unload_model();
  return [NSString stringWithUTF8String:status.c_str()];
}

- (NSString *)modelStatus {
  const std::string status = _engine->get_model_status();
  return [NSString stringWithUTF8String:status.c_str()];
}
@end
```

- [ ] **Step 5: Add Swift channel handler**

Create `flutter_app/macos/Runner/TranslatorChannelHandler.swift` exactly as:

```swift
import FlutterMacOS
import Foundation

class TranslatorChannelHandler: NSObject {
  private let bridge = TranslatorBridge()

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadModel":
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        let nCtx = args["nCtx"] as? Int,
        let nThreads = args["nThreads"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "loadModel 参数无效", details: nil))
        return
      }
      result(bridge.loadModel(atPath: path, nCtx: nCtx, nThreads: nThreads))
    case "translate":
      guard
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "translate 参数无效", details: nil))
        return
      }
      result(bridge.translate(text))
    case "cancel":
      result(bridge.cancel())
    case "unloadModel":
      result(bridge.unloadModel())
    case "getModelStatus":
      result(bridge.modelStatus())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```

- [ ] **Step 6: Register channel in AppDelegate**

Replace `flutter_app/macos/Runner/AppDelegate.swift` exactly as:

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let translatorChannelHandler = TranslatorChannelHandler()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "ai_offline_translator/translator",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.translatorChannelHandler.handle(call, result: result)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
```

- [ ] **Step 7: Add native sources to Xcode project**

Modify `flutter_app/macos/Runner.xcodeproj/project.pbxproj` so the following files are included in the Runner target:

- `TranslatorChannelHandler.swift`
- `Native/translator_bridge.mm`
- `Native/translator_engine.cpp`
- `Native/translator_engine.hpp`

The expected outcome is that `flutter run -d macos` builds without “file not found” or missing symbol errors for these sources.

- [ ] **Step 8: Run bounded macOS build validation**

Run:

```bash
cd flutter_app && timeout 60s /Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

Expected: app builds and launches, or exits by timeout after showing startup progress. The app should not fail on missing channel registration.

- [ ] **Step 9: Commit**

Run:

```bash
git add flutter_app/macos/Runner/AppDelegate.swift flutter_app/macos/Runner/TranslatorChannelHandler.swift flutter_app/macos/Runner/Native flutter_app/macos/Runner.xcodeproj/project.pbxproj
git commit -m "Add macOS translator bridge"
```

Expected: commit succeeds.

## Task 5: Wire Real macOS Service Into the Flutter Workspace

**Files:**
- Modify: `flutter_app/lib/app.dart`
- Modify: `flutter_app/lib/features/translator/translator_page.dart`
- Modify: `flutter_app/test/widget_test.dart`

- [ ] **Step 1: Add failing widget expectations for model workflow**

Replace `flutter_app/test/widget_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders model controls in translator workspace', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI 离线翻译'), findsOneWidget);
    expect(find.text('未加载模型'), findsOneWidget);
    expect(find.text('选择模型'), findsOneWidget);
    expect(find.text('加载模型'), findsOneWidget);
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because the current page has no model controls.

- [ ] **Step 2: Wire real service into app**

Replace `flutter_app/lib/app.dart` exactly as:

```dart
import 'package:flutter/material.dart';

import 'design/app_theme.dart';
import 'features/translator/macos_translator_service.dart';
import 'features/translator/translator_page.dart';

class OfflineTranslatorApp extends StatelessWidget {
  const OfflineTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 离线翻译',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: TranslatorPage(service: MacosTranslatorService()),
    );
  }
}
```

- [ ] **Step 3: Replace translator page with model-aware workspace**

Replace `flutter_app/lib/features/translator/translator_page.dart` exactly as:

```dart
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../design/app_colors.dart';
import '../../design/app_spacing.dart';
import 'translator_controller.dart';
import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({required this.service, super.key});

  final TranslatorService service;

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  late final TextEditingController _textController;
  late final TranslatorController _controller;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _controller = TranslatorController(service: widget.service);
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    const typeGroup = XTypeGroup(label: 'gguf', extensions: ['gguf']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      _controller.selectModel(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(status: state.runtimeStatus),
                      const SizedBox(height: AppSpacing.xl),
                      _ModelPanel(
                        state: state,
                        onPickModel: _pickModel,
                        onLoadModel: _controller.loadSelectedModel,
                        onUnloadModel: _controller.unloadModel,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _LanguageRow(
                        sourceLanguage: state.sourceLanguage,
                        targetLanguage: state.targetLanguage,
                        onSourceChanged: _controller.updateSourceLanguage,
                        onTargetChanged: _controller.updateTargetLanguage,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _textController,
                        minLines: 5,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '原文',
                          hintText: '输入要离线翻译的文本',
                        ),
                        onChanged: _controller.updateInput,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: state.canTranslate ? () => _controller.translate() : null,
                            child: const Text('翻译'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: state.status == TranslatorStatus.translating
                                ? _controller.cancel
                                : null,
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _textController.clear();
                              _controller.clear();
                            },
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Expanded(child: _OutputPanel(state: state)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI 离线翻译',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'macOS 首阶段真实推理链路',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.steel),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            status,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.successText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelPanel extends StatelessWidget {
  const _ModelPanel({
    required this.state,
    required this.onPickModel,
    required this.onLoadModel,
    required this.onUnloadModel,
  });

  final TranslatorState state;
  final Future<void> Function() onPickModel;
  final Future<void> Function() onLoadModel;
  final Future<void> Function() onUnloadModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('模型', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(state.modelState.displayName ?? '未选择模型', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(onPressed: onPickModel, child: const Text('选择模型')),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: state.modelState.hasSelectedModel ? onLoadModel : null,
                child: const Text('加载模型'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: state.modelState.status == ModelLifecycleStatus.ready ? onUnloadModel : null,
                child: const Text('卸载模型'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceChanged,
    required this.onTargetChanged,
  });

  static const languages = ['英语', '中文', '日语', '韩语'];

  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LanguageMenu(
            label: '源语言',
            value: sourceLanguage,
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _LanguageMenu(
            label: '目标语言',
            value: targetLanguage,
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: _LanguageRow.languages
          .map((language) => DropdownMenuItem(value: language, child: Text(language)))
          .toList(),
      onChanged: (language) {
        if (language != null) {
          onChanged(language);
        }
      },
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({required this.state});

  final TranslatorState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contentColor = state.status == TranslatorStatus.error ? AppColors.errorText : AppColors.ink;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('译文', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                switch (state.status) {
                  TranslatorStatus.idle => '译文会显示在这里。',
                  TranslatorStatus.ready => '准备好了。',
                  TranslatorStatus.translating => '正在翻译...',
                  TranslatorStatus.completed => state.outputText,
                  TranslatorStatus.cancelled => '翻译已取消。',
                  TranslatorStatus.error => state.errorMessage ?? '出现错误。',
                },
                style: textTheme.bodyLarge?.copyWith(color: contentColor, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests and analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add flutter_app/lib/app.dart flutter_app/lib/features/translator/translator_page.dart flutter_app/test/widget_test.dart
git commit -m "Add model selection workflow"
```

Expected: commit succeeds.

## Task 6: Replace Temporary Native Engine With Real llama.cpp Loading on macOS

**Files:**
- Modify: `flutter_app/macos/Runner/Native/translator_engine.hpp`
- Modify: `flutter_app/macos/Runner/Native/translator_engine.cpp`

- [ ] **Step 1: Add bounded real-engine smoke behavior requirements**

Before editing code, capture the intended constraints in a temporary note in your scratchpad (do not commit this note):

- single loaded model at a time
- bounded `n_ctx=256`
- bounded `n_threads=2`
- no interactive loop
- one translation request per user action
- unload resets engine state completely

- [ ] **Step 2: Replace header with real engine state**

Replace `flutter_app/macos/Runner/Native/translator_engine.hpp` exactly as:

```cpp
#pragma once

#include <memory>
#include <string>

struct llama_model;
struct llama_context;

class TranslatorEngine {
 public:
  TranslatorEngine();
  ~TranslatorEngine();

  std::string load_model(const std::string& model_path, int n_ctx, int n_threads);
  std::string translate(const std::string& prompt);
  std::string cancel();
  std::string unload_model();
  std::string get_model_status() const;

 private:
  bool cancel_requested_;
  bool model_loaded_;
  int n_ctx_;
  int n_threads_;
  std::string model_path_;
  std::string status_;
  llama_model* model_;
  llama_context* context_;
};
```

- [ ] **Step 3: Implement real llama.cpp loading and bounded translation**

Replace `flutter_app/macos/Runner/Native/translator_engine.cpp` with an implementation that:

1. includes `llama.h` from `third_party/llama.cpp/include/llama.h`
2. calls `llama_backend_init()` during load if needed
3. loads the model from file path with `llama_model_load_from_file`
4. creates a context with bounded `n_ctx` and thread count
5. tokenizes the prompt
6. evaluates the prompt
7. greedily generates a bounded number of tokens
8. stops if EOS is reached or `cancel_requested_` becomes true
9. returns UTF-8 text output
10. unloads model/context safely

Use these exact implementation constraints:

- maximum generated tokens: `128`
- default context from caller: `256`
- default threads from caller: `2`
- if no model is loaded, `translate()` returns `未加载模型`
- if load fails, return `模型加载失败`
- if cancelled, return `翻译已取消`

Do not add benchmark support, chat mode, or streaming callbacks in this task.

- [ ] **Step 4: Run bounded app validation**

Run:

```bash
cd flutter_app && timeout 60s /Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

Expected: app builds successfully with the real engine linked in.

- [ ] **Step 5: Manual real translation smoke test**

Run the app and manually verify this exact flow:

1. choose `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
2. click `加载模型`
3. input `Hello`
4. click `翻译`

Expected: output is a real translation, ideally `你好` or semantically equivalent Chinese output, and not the raw prompt string.

If manual verification requires interactive app usage beyond shell automation, record the exact observed result in the commit message body or final report.

- [ ] **Step 6: Commit**

Run:

```bash
git add flutter_app/macos/Runner/Native/translator_engine.hpp flutter_app/macos/Runner/Native/translator_engine.cpp
git commit -m "Integrate llama.cpp on macOS"
```

Expected: commit succeeds.

## Task 7: Final Documentation and Validation

**Files:**
- Modify: `README.md`
- Optional modify: `docs/flutter_mobile_architecture.md`

- [ ] **Step 1: Update README Flutter section**

Add or revise the Flutter section in `README.md` so it explicitly states:

- macOS now supports real local-model inference
- model selection is manual in phase 1
- recommended local file is `models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/Hy-MT1.5-1.8B-STQ1_0.gguf`
- Android/iOS native inference remains future work

Also include these commands exactly:

```bash
cd flutter_app
/Users/fh/Projects/Flutter/flutter/bin/flutter test
/Users/fh/Projects/Flutter/flutter/bin/flutter analyze
/Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

- [ ] **Step 2: Optional architecture doc adjustment**

If `docs/flutter_mobile_architecture.md` still implies only a mock scaffold, add a short note that macOS is now the first real-inference target and that manual local model selection precedes download management.

- [ ] **Step 3: Run final validation**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 4: Confirm working tree state**

Run:

```bash
git status --short --branch
```

Expected: only intended doc changes remain before commit; after commit, the implementation branch is clean.

- [ ] **Step 5: Commit**

Run:

```bash
git add README.md docs/flutter_mobile_architecture.md
git commit -m "Document macOS inference flow"
```

If `docs/flutter_mobile_architecture.md` was not edited, omit it from the `git add` command.
