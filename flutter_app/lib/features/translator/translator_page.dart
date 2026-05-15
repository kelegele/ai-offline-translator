import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../../design/app_spacing.dart';
import 'translator_controller.dart';
import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  late final TextEditingController _textController;
  late final TranslatorController _controller;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _controller = TranslatorController(service: const MockTranslatorService());
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(status: _statusLabel(state.status)),
                      const SizedBox(height: AppSpacing.xl),
                      _LanguageRow(
                        sourceLanguage: state.sourceLanguage,
                        targetLanguage: state.targetLanguage,
                        onSourceChanged: _controller.updateSourceLanguage,
                        onTargetChanged: _controller.updateTargetLanguage,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _textController,
                        minLines: 5,
                        maxLines: 8,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Source text',
                          hintText: 'Enter text to translate offline',
                        ),
                        onChanged: _controller.updateInput,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: state.status == TranslatorStatus.translating
                                ? null
                                : () => _controller.translate(_textController.text),
                            child: const Text('Translate'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: state.status == TranslatorStatus.translating
                                ? _controller.cancel
                                : null,
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _textController.clear();
                              _controller.clear();
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Expanded(child: _OutputPanel(state: state)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(TranslatorStatus status) {
    return switch (status) {
      TranslatorStatus.idle => 'Local model ready',
      TranslatorStatus.ready => 'Ready to translate',
      TranslatorStatus.translating => 'Translating locally',
      TranslatorStatus.completed => 'Translation complete',
      TranslatorStatus.cancelled => 'Translation cancelled',
      TranslatorStatus.error => 'Needs attention',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Offline Translator',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Flutter UI scaffold with a future native llama.cpp bridge.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.steel),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            status,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.successText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceChanged,
    required this.onTargetChanged,
  });

  static const languages = ['English', 'Chinese', 'Japanese', 'Korean'];

  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LanguageMenu(
            label: 'From',
            value: sourceLanguage,
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _LanguageMenu(
            label: 'To',
            value: targetLanguage,
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: _LanguageRow.languages
          .map((language) => DropdownMenuItem(value: language, child: Text(language)))
          .toList(),
      onChanged: (language) {
        if (language != null) {
          onChanged(language);
        }
      },
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({required this.state});

  final TranslatorState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = _contentForState();
    final contentColor =
        state.status == TranslatorStatus.error ? AppColors.errorText : AppColors.ink;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Output',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                content,
                style: textTheme.bodyLarge?.copyWith(color: contentColor, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _contentForState() {
    return switch (state.status) {
      TranslatorStatus.idle => 'Translation output will appear here.',
      TranslatorStatus.ready => 'Ready when you are.',
      TranslatorStatus.translating => 'Translating...',
      TranslatorStatus.completed => state.outputText,
      TranslatorStatus.cancelled => 'Translation cancelled.',
      TranslatorStatus.error => state.errorMessage ?? 'Something went wrong.',
    };
  }
}
