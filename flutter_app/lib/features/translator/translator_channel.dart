class TranslatorChannel {
  const TranslatorChannel();

  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
    throw UnimplementedError('Native model loading is not connected yet.');
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    throw UnimplementedError('Native translation is not connected yet.');
  }

  Future<void> cancel() {
    throw UnimplementedError('Native cancellation is not connected yet.');
  }

  Future<void> unloadModel() {
    throw UnimplementedError('Native model unloading is not connected yet.');
  }

  Future<String> getModelStatus() async {
    return 'Native bridge not connected';
  }
}
