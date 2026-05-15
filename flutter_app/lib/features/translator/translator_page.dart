import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_colors.dart';
import '../../design/app_spacing.dart';
import 'macos_translator_service.dart';
import 'model_selection_state.dart';
import 'translator_channel.dart';
import 'translator_controller.dart';
import 'translator_state.dart';

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  late final TextEditingController _textController;
  late final TextEditingController _modelPathController;
  late final TranslatorController _controller;
  final TranslatorChannel _translatorChannel = const TranslatorChannel();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _modelPathController = TextEditingController();
    _controller = TranslatorController(
      service: createDefaultTranslatorService(),
    );
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _modelPathController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // rebuild for character counter
  }

  int get _characterCount {
    final text = _textController.text;
    return RegExp(r'[\w\u4e00-\u9fff\u3400-\u4dbf]').allMatches(text).length;
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
                  child: ListView(
                    children: [
                      _Header(
                        status: _statusLabel(state),
                        subtitle: _subtitle(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ModelPanel(
                        state: state,
                        controller: _modelPathController,
                        onPathChanged: (value) =>
                            _controller.selectModel(value),
                        onImportPressed: Platform.isMacOS
                            ? _importModelFile
                            : null,
                        onLoadPressed: _controller.loadSelectedModel,
                        onUnloadPressed: state.modelState.hasSelection
                            ? _controller.unloadModel
                            : null,
                      ),
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
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$_characterCount/200',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.steel),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          FilledButton(
                            onPressed:
                                state.status == TranslatorStatus.translating ||
                                    !state.canTranslate
                                ? null
                                : () => _controller.translate(
                                    _textController.text,
                                  ),
                            child: const Text('翻译'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton(
                            onPressed:
                                state.status == TranslatorStatus.translating
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
                      SizedBox(height: 260, child: _OutputPanel(state: state)),
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

  Future<void> _importModelFile() async {
    final path = await _translatorChannel.importModelFile();
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _modelPathController.text = path;
    _controller.selectModel(path);
  }

  String _subtitle() {
    if (Platform.isMacOS) {
      return 'macOS 首版使用原生 llama.cpp 引擎，模型导入到 App 私有目录。';
    }
    return '当前平台仍使用 mock service，macOS 优先接入真推理。';
  }

  String _statusLabel(TranslatorState state) {
    if (state.status == TranslatorStatus.translating) {
      return '正在本地翻译';
    }
    if (state.status == TranslatorStatus.completed) {
      return '翻译完成';
    }
    if (state.status == TranslatorStatus.cancelled) {
      return '翻译已取消';
    }
    if (state.status == TranslatorStatus.error) {
      return '需要处理';
    }
    return state.runtimeStatus;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.subtitle});

  final String status;
  final String subtitle;

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
                subtitle,
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

class _ModelPanel extends StatelessWidget {
  const _ModelPanel({
    required this.state,
    required this.controller,
    required this.onPathChanged,
    required this.onImportPressed,
    required this.onLoadPressed,
    required this.onUnloadPressed,
  });

  final TranslatorState state;
  final TextEditingController controller;
  final ValueChanged<String> onPathChanged;
  final Future<void> Function()? onImportPressed;
  final Future<void> Function() onLoadPressed;
  final Future<void> Function()? onUnloadPressed;

  @override
  Widget build(BuildContext context) {
    final helperText = state.modelState.displayName == null
        ? '推荐导入 GGUF 到 App 私有目录；也可手动输入路径'
        : '当前模型：${state.modelState.displayName}';

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
            '模型',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'GGUF 路径',
              hintText: '粘贴本地模型路径',
              helperText: helperText,
              errorText: state.modelState.errorMessage,
            ),
            onChanged: onPathChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: onImportPressed,
                child: const Text('导入模型'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed:
                    state.modelState.status == ModelLifecycleStatus.loading
                    ? null
                    : onLoadPressed,
                child: const Text('加载模型'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed:
                    state.modelState.status == ModelLifecycleStatus.unloading
                    ? null
                    : onUnloadPressed,
                child: const Text('卸载模型'),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  state.runtimeStatus,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.steel),
                ),
              ),
            ],
          ),
        ],
      ),
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
          .map(
            (language) =>
                DropdownMenuItem(value: language, child: Text(language)),
          )
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
    final contentColor = state.status == TranslatorStatus.error
        ? AppColors.errorText
        : AppColors.ink;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '译文',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: state.status == TranslatorStatus.completed
                      ? () {
                          Clipboard.setData(
                            ClipboardData(text: state.outputText),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                content,
                style: textTheme.bodyLarge?.copyWith(
                  color: contentColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _contentForState() {
    return switch (state.status) {
      TranslatorStatus.idle => '请先加载模型，然后开始翻译。',
      TranslatorStatus.ready => state.modelState.isReady ? '准备好了。' : '请先加载模型。',
      TranslatorStatus.translating => '正在翻译...',
      TranslatorStatus.completed => state.outputText,
      TranslatorStatus.cancelled => '翻译已取消。',
      TranslatorStatus.error => state.errorMessage ?? '出现错误。',
    };
  }
}
