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
      'Please translate to 中文, without additional explanation:\n\nHello world',
    );
  });
}
