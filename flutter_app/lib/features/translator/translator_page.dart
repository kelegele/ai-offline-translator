import 'dart:async';
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
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
  late final TranslatorController _controller;
  final TranslatorChannel _translatorChannel = const TranslatorChannel();
  Timer? _downloadPollTimer;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _controller = TranslatorController(
      service: createDefaultTranslatorService(),
    );
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _downloadPollTimer?.cancel();
    _textController.dispose();
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

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

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
                  padding: EdgeInsets.symmetric(
                    horizontal: _isMobile ? AppSpacing.md : AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: ListView(
                    children: [
                      _Header(
                        status: _statusLabel(state),
                        subtitle: _subtitle(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ModelPanel(
                        state: state,
                        onImportPressed: Platform.isMacOS || Platform.isAndroid
                            ? _importModel
                            : null,
                        onDownloadPressed:
                            Platform.isMacOS || Platform.isAndroid
                            ? _downloadDefaultModel
                            : null,
                        onCancelDownloadPressed:
                            state.modelDownloadState.isDownloading
                            ? _cancelModelDownload
                            : null,
                        onLoadPressed: _controller.loadSelectedModel,
                        onUnloadPressed: state.modelState.hasSelection
                            ? _controller.unloadModel
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LanguageRow(
                        sourceLanguage: state.sourceLanguage,
                        targetLanguage: state.targetLanguage,
                        onSourceChanged: _controller.updateSourceLanguage,
                        onTargetChanged: _controller.updateTargetLanguage,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _textController,
                        minLines: 4,
                        maxLines: 6,
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
                      const SizedBox(height: AppSpacing.sm),
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
                      const SizedBox(height: AppSpacing.md),
                      _OutputPanel(state: state),
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

  Future<void> _importModel() async {
    String? path;
    if (Platform.isAndroid) {
      path = await _importAndroidModel();
    } else {
      path = await _translatorChannel.importModelFile();
    }
    if (path == null || path.trim().isEmpty) {
      return;
    }
    _controller.selectModel(path);
  }

  Future<String?> _importAndroidModel() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
      );
      if (picked == null || picked.files.isEmpty) return null;
      final uri = picked.files.first.path;
      if (uri == null) return null;
      return await _translatorChannel.invokeMethod<String>(
        'importModelFromUri',
        {'uri': uri},
      );
    } on PlatformException {
      return null;
    }
  }

  Future<void> _downloadDefaultModel() async {
    _controller.beginModelDownload();
    _startDownloadPolling();
    try {
      final path = await _translatorChannel.downloadDefaultModel();
      _downloadPollTimer?.cancel();
      if (path == null || path.trim().isEmpty) {
        _controller.cancelModelDownload();
        return;
      }
      _controller.startModelDownload(path);
    } on Object {
      _downloadPollTimer?.cancel();
      _controller.failModelDownload('模型下载失败，请检查网络后重试。');
    }
  }

  Future<void> _cancelModelDownload() async {
    await _translatorChannel.cancelModelDownload();
    _downloadPollTimer?.cancel();
    _controller.cancelModelDownload();
  }

  void _startDownloadPolling() {
    _downloadPollTimer?.cancel();
    _downloadPollTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      try {
        final status = await _translatorChannel.getModelDownloadStatus();
        final state = status['state'] as String? ?? 'idle';
        if (state == 'downloading') {
          final received = (status['receivedBytes'] as num?)?.toInt() ?? 0;
          final total = (status['totalBytes'] as num?)?.toInt() ?? 0;
          final message = status['message'] as String? ?? '';
          _controller.updateModelDownloadProgress(
            receivedBytes: received,
            totalBytes: total,
            message: message,
          );
        }
      } on Object {
        // ignore polling errors
      }
    });
  }

  String _statusLabel(TranslatorState state) {
    return switch (state.status) {
      TranslatorStatus.idle => 'AI 离线翻译',
      TranslatorStatus.ready => 'AI 离线翻译',
      TranslatorStatus.translating => '正在翻译…',
      TranslatorStatus.completed => '翻译完成',
      TranslatorStatus.cancelled => '已取消',
      TranslatorStatus.error => '出错了',
    };
  }

  String _subtitle() {
    return switch (_controller.state.status) {
      TranslatorStatus.idle => '请先加载模型',
      TranslatorStatus.ready => _controller.state.modelState.isReady ? '准备好了。' : '请先加载模型。',
      TranslatorStatus.translating => '请稍候…',
      TranslatorStatus.completed => '可以继续翻译',
      TranslatorStatus.cancelled => '已取消翻译',
      TranslatorStatus.error => _controller.state.errorMessage ?? '出现错误',
    };
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          status,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.successBackground,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            subtitle,
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
    required this.onImportPressed,
    required this.onDownloadPressed,
    required this.onCancelDownloadPressed,
    required this.onLoadPressed,
    required this.onUnloadPressed,
  });

  final TranslatorState state;
  final Future<void> Function()? onImportPressed;
  final Future<void> Function()? onDownloadPressed;
  final Future<void> Function()? onCancelDownloadPressed;
  final Future<void> Function() onLoadPressed;
  final Future<void> Function()? onUnloadPressed;

  @override
  Widget build(BuildContext context) {
    final modelName = state.modelState.displayName ?? '未选择模型';
    final modelHint = state.modelState.displayName == null
        ? '请导入本地 GGUF，或从 ModelScope 下载默认模型'
        : '模型已保存到 App 私有目录';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(
                color: state.modelState.errorMessage == null
                    ? AppColors.hairline
                    : AppColors.errorText,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前模型',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.steel),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  modelName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.modelState.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    state.modelState.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.errorText),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    modelHint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Action buttons: wrap on small screens
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: onImportPressed,
                child: const Text('导入模型'),
              ),
              OutlinedButton(
                onPressed: state.modelDownloadState.isDownloading
                    ? null
                    : onDownloadPressed,
                child: const Text('下载模型'),
              ),
              if (state.modelDownloadState.isDownloading)
                OutlinedButton(
                  onPressed: onCancelDownloadPressed,
                  child: const Text('取消下载'),
                ),
              FilledButton(
                onPressed:
                    state.modelState.status == ModelLifecycleStatus.loading
                    ? null
                    : onLoadPressed,
                child: const Text('加载模型'),
              ),
              OutlinedButton(
                onPressed:
                    state.modelState.status == ModelLifecycleStatus.unloading
                    ? null
                    : onUnloadPressed,
                child: const Text('卸载模型'),
              ),
            ],
          ),
          if (state.modelDownloadState.isDownloading) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.modelDownloadState.progressLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: textTheme.bodyLarge?.copyWith(
              color: contentColor,
              height: 1.5,
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
