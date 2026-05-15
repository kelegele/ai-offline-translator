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
    setState(() {});
  }

  int get _characterCount {
    final text = _textController.text;
    return RegExp(r'[\w\u4e00-\u9fff\u3400-\u4dbf]').allMatches(text).length;
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  // --- Model bottom sheet ---

  void _showModelSheet() {
    final state = _controller.state;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ModelSheet(
        state: state,
        onImport: () {
          Navigator.pop(context);
          _importModel();
        },
        onDownload: () {
          Navigator.pop(context);
          _downloadDefaultModel();
        },
        onLoad: () {
          Navigator.pop(context);
          _controller.loadSelectedModel();
        },
        onUnload: () {
          Navigator.pop(context);
          _controller.unloadModel();
        },
        onCancelDownload: () {
          Navigator.pop(context);
          _cancelModelDownload();
        },
      ),
    );
  }

  // --- Model actions ---

  Future<void> _importModel() async {
    String? path;
    if (Platform.isAndroid) {
      path = await _importAndroidModel();
    } else {
      path = await _translatorChannel.importModelFile();
    }
    if (path == null || path.trim().isEmpty) return;
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
        // polling errors ignored
      }
    });
  }

  // --- Build ---

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
                child: Column(
                  children: [
                    _buildNavBar(state),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isMobile ? AppSpacing.md : AppSpacing.xl,
                          vertical: AppSpacing.md,
                        ),
                        children: [
                          _LanguageRow(
                            sourceLanguage: state.sourceLanguage,
                            targetLanguage: state.targetLanguage,
                            onSourceChanged: _controller.updateSourceLanguage,
                            onTargetChanged: _controller.updateTargetLanguage,
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                                    state.status ==
                                            TranslatorStatus.translating ||
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavBar(TranslatorState state) {
    final isLoaded = state.modelState.isReady;
    final modelName = state.modelState.displayName;
    final isDownloading = state.modelDownloadState.isDownloading;

    String label;
    IconData icon;
    Color bgColor;
    Color textColor;

    if (isDownloading) {
      label = '下载中…';
      icon = Icons.cloud_download;
      bgColor = AppColors.brandBlue.withValues(alpha: 0.1);
      textColor = AppColors.brandBlue;
    } else if (isLoaded && modelName != null) {
      label = modelName.length > 12
          ? '${modelName.substring(0, 12)}…'
          : modelName;
      icon = Icons.check_circle;
      bgColor = AppColors.successBackground;
      textColor = AppColors.successText;
    } else {
      label = '未加载';
      icon = Icons.warning_amber;
      bgColor = const Color(0xFFFFF3CD);
      textColor = const Color(0xFF856404);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Text(
            'AI 离线翻译',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showModelSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Model Bottom Sheet ---

class _ModelSheet extends StatelessWidget {
  const _ModelSheet({
    required this.state,
    required this.onImport,
    required this.onDownload,
    required this.onLoad,
    required this.onUnload,
    required this.onCancelDownload,
  });

  final TranslatorState state;
  final VoidCallback onImport;
  final VoidCallback onDownload;
  final VoidCallback onLoad;
  final VoidCallback onUnload;
  final VoidCallback onCancelDownload;

  @override
  Widget build(BuildContext context) {
    final modelName = state.modelState.displayName ?? '未选择模型';
    final isLoaded = state.modelState.isReady;
    final hasSelection = state.modelState.hasSelection;
    final isDownloading = state.modelDownloadState.isDownloading;
    final isLoading = state.modelState.status == ModelLifecycleStatus.loading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '模型管理',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(10),
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
                const SizedBox(height: 4),
                Text(
                  modelName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLoaded ? AppColors.successText : AppColors.ink,
                  ),
                ),
                if (state.modelState.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.modelState.errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.errorText),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    hasSelection
                        ? '模型已保存到 App 私有目录'
                        : '请导入本地 GGUF，或从 ModelScope 下载默认模型',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isDownloading ? null : onImport,
                icon: const Icon(Icons.file_upload, size: 18),
                label: const Text('导入'),
              ),
              OutlinedButton.icon(
                onPressed: isDownloading ? null : onDownload,
                icon: const Icon(Icons.cloud_download, size: 18),
                label: const Text('下载'),
              ),
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: onCancelDownload,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('取消下载'),
                ),
              if (hasSelection)
                FilledButton.icon(
                  onPressed: isLoading ? null : onLoad,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('加载'),
                ),
              if (isLoaded)
                OutlinedButton.icon(
                  onPressed: onUnload,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('卸载'),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            Text(
              state.modelDownloadState.progressLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            isLoaded ? '✅ 本地模型已就绪' : '⚠️ 未加载模型',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isLoaded ? AppColors.successText : AppColors.steel,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Language Row ---

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

// --- Output Panel ---

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
