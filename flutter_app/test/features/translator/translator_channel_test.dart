import 'package:ai_offline_translator/features/translator/translator_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'test_translator_channel';
  const methodChannel = MethodChannel(channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('translateStream pulls tokens after beginning translation', () async {
    final calls = <String>[];
    final tokens = <String?>['你', '好', null];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'beginTranslation':
              return null;
            case 'generateNextToken':
              return tokens.removeAt(0);
            default:
              fail('unexpected method ${call.method}');
          }
        });

    final translatorChannel = TranslatorChannel(channel: methodChannel);

    final chunks = await translatorChannel
        .translateStream(
          text: 'Hello',
          sourceLanguage: '英语',
          targetLanguage: '中文',
          modelPath: '/tmp/model.gguf',
        )
        .toList();

    expect(chunks, ['你', '好']);
    expect(calls, [
      'beginTranslation',
      'generateNextToken',
      'generateNextToken',
      'generateNextToken',
    ]);
  });
}
