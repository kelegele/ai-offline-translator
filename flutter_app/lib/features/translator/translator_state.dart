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
    this.errorMessage,
  });

  final TranslatorStatus status;
  final String inputText;
  final String outputText;
  final String sourceLanguage;
  final String targetLanguage;
  final String? errorMessage;

  bool get canTranslate =>
      inputText.trim().isNotEmpty && status != TranslatorStatus.translating;

  TranslatorState copyWith({
    TranslatorStatus? status,
    String? inputText,
    String? outputText,
    String? sourceLanguage,
    String? targetLanguage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TranslatorState(
      status: status ?? this.status,
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
