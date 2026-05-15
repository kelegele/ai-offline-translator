import 'package:file_picker/file_picker.dart';

import 'translator_channel.dart';
import 'translator_service.dart';

class AndroidTranslatorService implements TranslatorService {
  AndroidTranslatorService({TranslatorChannel? channel})
    : _channel = channel ?? const TranslatorChannel();

  final TranslatorChannel _channel;
  String? _modelPath;

  /// Pick a GGUF file via system file picker, import it to app-private
  /// models directory via native bridge, and return the imported path.
  Future<String?> pickAndImportModel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    if (result == null || result.files.isEmpty) return null;

    final platformFile = result.files.first;
    final uri = platformFile.path;
    if (uri == null) return null;

    final importedPath = await _channel.invokeMethod<String>(
      'importModelFromUri',
      {'uri': uri},
    );
    if (importedPath != null) {
      _modelPath = importedPath;
    }
    return importedPath;
  }

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
    _modelPath = path;
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
      modelPath: _modelPath ?? '',
    );
  }

  @override
  Future<void> cancel() {
    return _channel.cancel();
  }

  @override
  Future<void> unloadModel() {
    return _channel.unloadModel();
  }

  @override
  Future<String> getModelStatus() {
    return _channel.getModelStatus();
  }
}
