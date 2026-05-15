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
        normalized == 'hello') {
      return '你好';
    }

    return '[$targetLanguage] ${text.trim()}';
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
