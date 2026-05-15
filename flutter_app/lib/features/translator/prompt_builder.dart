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

    return 'Please translate to $targetLanguage, without additional explanation:\n\n$trimmed';
  }
}
