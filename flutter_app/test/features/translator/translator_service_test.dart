import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock service returns deterministic Chinese translation', () async {
    const service = MockTranslatorService();

    final result = await service.translate(
      text: 'Hello',
      sourceLanguage: '英语',
      targetLanguage: '中文',
    );

    expect(result, '你好');
  });

  test('mock service echoes unsupported text with target language', () async {
    const service = MockTranslatorService();

    final result = await service.translate(
      text: 'Good morning',
      sourceLanguage: '英语',
      targetLanguage: '中文',
    );

    expect(result, '[中文] Good morning');
  });
}
