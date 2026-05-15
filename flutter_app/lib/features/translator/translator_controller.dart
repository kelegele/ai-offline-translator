import 'package:flutter/foundation.dart';

import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorController extends ChangeNotifier {
  TranslatorController({required TranslatorService service}) : _service = service;

  final TranslatorService _service;

  TranslatorState _state = const TranslatorState();
  int _requestToken = 0;

  TranslatorState get state => _state;

  void updateInput(String text) {
    _state = _state.copyWith(
      inputText: text,
      status: text.trim().isEmpty ? TranslatorStatus.idle : TranslatorStatus.ready,
      clearError: true,
    );
    notifyListeners();
  }

  void updateSourceLanguage(String language) {
    _state = _state.copyWith(sourceLanguage: language, clearError: true);
    notifyListeners();
  }

  void updateTargetLanguage(String language) {
    _state = _state.copyWith(targetLanguage: language, clearError: true);
    notifyListeners();
  }

  Future<void> translate([String? text]) async {
    final trimmed = (text ?? _state.inputText).trim();
    if (trimmed.isEmpty) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        inputText: text,
        errorMessage: 'Enter text to translate.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: TranslatorStatus.translating,
      inputText: trimmed,
      outputText: '',
      clearError: true,
    );
    notifyListeners();

    final requestToken = ++_requestToken;

    try {
      final output = await _service.translate(
        text: trimmed,
        sourceLanguage: _state.sourceLanguage,
        targetLanguage: _state.targetLanguage,
      );
      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.completed,
        outputText: output,
        clearError: true,
      );
    } on Object catch (error) {
      if (requestToken != _requestToken) {
        return;
      }
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        errorMessage: error is StateError ? error.message : error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    _requestToken++;
    await _service.cancel();
    _state = _state.copyWith(status: TranslatorStatus.cancelled);
    notifyListeners();
  }

  void clear() {
    _state = const TranslatorState();
    notifyListeners();
  }
}
