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
                          labelText: '原文',
                          hintText: '输入要离线翻译的文本',
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
                            child: const Text('翻译'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                            onPressed: state.status == TranslatorStatus.translating
                                ? _controller.cancel
                                : null,
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _textController.clear();
                              _controller.clear();
                            },
                            child: const Text('清空'),
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
      TranslatorStatus.idle => '本地模型已就绪',
      TranslatorStatus.ready => '准备翻译',
      TranslatorStatus.translating => '正在本地翻译',
      TranslatorStatus.completed => '翻译完成',
      TranslatorStatus.cancelled => '翻译已取消',
      TranslatorStatus.error => '需要处理',
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
                'AI 离线翻译',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Flutter UI 骨架，后续接入原生 llama.cpp。',
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

  static const languages = ['英语', '中文', '日语', '韩语'];

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
            label: '源语言',
            value: sourceLanguage,
            onChanged: onSourceChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _LanguageMenu(
            label: '目标语言',
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
            '译文',
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
      TranslatorStatus.idle => '译文会显示在这里。',
      TranslatorStatus.ready => '准备好了。',
      TranslatorStatus.translating => '正在翻译...',
      TranslatorStatus.completed => state.outputText,
      TranslatorStatus.cancelled => '翻译已取消。',
      TranslatorStatus.error => state.errorMessage ?? '出现错误。',
    };
  }
}
