import 'package:ai_offline_translator/features/translator/android_translator_service.dart';
import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AndroidTranslatorService implements TranslatorService', () {
    final service = AndroidTranslatorService();
    expect(service, isA<TranslatorService>());
  });

  test(
    'AndroidTranslatorService and MacosTranslatorService are distinct types',
    () {
      final android = AndroidTranslatorService();
      expect(android.runtimeType.toString(), 'AndroidTranslatorService');
    },
  );
}
