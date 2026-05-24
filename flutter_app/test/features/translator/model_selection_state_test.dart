import 'package:ai_offline_translator/features/translator/local_model_info.dart';
import 'package:ai_offline_translator/features/translator/model_selection_state.dart';
import 'package:ai_offline_translator/features/translator/supported_model_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalModelInfo parses channel maps and exposes file name fallback', () {
    final model = LocalModelInfo.fromMap({
      'path': '/app/models/Hy-MT2-1.8B-1.25Bit.gguf',
      'sizeBytes': 461373440,
    });

    expect(model.path, '/app/models/Hy-MT2-1.8B-1.25Bit.gguf');
    expect(model.name, 'Hy-MT2-1.8B-1.25Bit.gguf');
    expect(model.sizeBytes, 461373440);
  });

  test('supported models include Hy-MT2 1.25bit HF-Mirror default', () {
    expect(supportedTranslatorModels, hasLength(1));
    final model = supportedTranslatorModels.single;

    expect(model.id, 'hymt2_18b_125bit');
    expect(model.filename, 'Hy-MT2-1.8B-1.25Bit.gguf');
    expect(
      model.downloadUrl,
      'https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF/resolve/main/Hy-MT2-1.8B-1.25Bit.gguf',
    );
  });

  test('state tracks selected and loaded model separately', () {
    const local = LocalModelInfo(
      path: '/app/models/Hy-MT2-1.8B-1.25Bit.gguf',
      name: 'Hy-MT2-1.8B-1.25Bit.gguf',
      sizeBytes: 461373440,
    );

    final state = ModelSelectionState(
      availableModels: [local],
      selectedPath: local.path,
      loadedPath: '/app/models/old.gguf',
      displayName: local.name,
    );

    expect(state.hasSelection, isTrue);
    expect(state.isLoadedSelection, isFalse);
    expect(state.loadedPath, '/app/models/old.gguf');
  });
}
