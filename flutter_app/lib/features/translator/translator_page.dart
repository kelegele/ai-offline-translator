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

  void _onTextChanged() => setState(() {});

  int get _characterCount {
    final text = _textController.text;
    return RegExp(r'[\w\u4e00-\u9fff\u3400-\u4dbf]').allMatches(text).length;
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  // --- Model sheet (stays open during import) ---

  void _showModelSheet() {
    // state read below // used in builder
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ModelSheet(
        state: _controller.state,
        onImport: () => _importModelFromSheet(sheetContext),
        onDownload: () {
          Navigator.pop(sheetContext);
          _downloadDefaultModel();
        },
        onLoad: () {
          Navigator.pop(sheetContext);
          _controller.loadSelectedModel();
        },
        onUnload: () {
          Navigator.pop(sheetContext);
          _controller.unloadModel();
        },
        onCancelDownload: () {
          Navigator.pop(sheetContext);
          _cancelModelDownload();
        },
      ),
    );
  }

  Future<void> _importModelFromSheet(BuildContext sheetContext) async {
    String? path;
    if (Platform.isAndroid) {
      path = await _importAndroidModel();
    } else {
      path = await _translatorChannel.importModelFile();
    }
    if (path != null && path.trim().isNotEmpty) {
      _controller.selectModel(path);
    }
    // sheet stays open so user can see model name and click 加载
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
      _controller.failModelDownload('下载失败，请检查网络后重试。');
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
        final st = status['state'] as String? ?? 'idle';
        if (st == 'downloading') {
          _controller.updateModelDownloadProgress(
            receivedBytes: (status['receivedBytes'] as num?)?.toInt() ?? 0,
            totalBytes: (status['totalBytes'] as num?)?.toInt() ?? 0,
            message: status['message'] as String? ?? '',
          );
        }
      } on Object {
        // ignore
      }
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state; // used in builder
        final isMobile = _isMobile;
        final hPadding = isMobile ? AppSpacing.md : 48.0;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            child: Column(
              children: [
                _buildNavBar(state),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            hPadding,
                            AppSpacing.md,
                            hPadding,
                            0,
                          ),
                          child: Column(
                            children: [
                              _LangBar(
                                sourceLanguage: state.sourceLanguage,
                                targetLanguage: state.targetLanguage,
                                onSourceChanged:
                                    _controller.updateSourceLanguage,
                                onTargetChanged:
                                    _controller.updateTargetLanguage,
                                onSwap: () {
                                  _controller.updateSourceLanguage(
                                    state.targetLanguage,
                                  );
                                  _controller.updateTargetLanguage(
                                    state.sourceLanguage,
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _InputPanel(
                                controller: _textController,
                                characterCount: _characterCount,
                                onChanged: _controller.updateInput,
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
                                        state.status ==
                                            TranslatorStatus.translating
                                        ? _controller.cancel
                                        : null,
                                    child: const Text('取消'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ),
                        ),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPadding),
                          child: _OutputPanel(state: state),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom:
                                AppSpacing.md +
                                MediaQuery.of(context).padding.bottom,
                          ),
                          child: Center(
                            child: Text(
                              '结果由 AI 生成，仅供参考',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Nav bar ---

  Widget _buildNavBar(TranslatorState state) {
    final isLoaded = state.modelState.isReady;
    final modelName = state.modelState.displayName;
    final isDownloading = state.modelDownloadState.isDownloading;

    String label;
    Color bgColor;
    Color textColor;

    if (isDownloading) {
      label = '下载中…';
      bgColor = AppColors.brandBlue.withValues(alpha: 0.1);
      textColor = AppColors.brandBlue;
    } else if (isLoaded && modelName != null) {
      label = modelName.length > 14
          ? '${modelName.substring(0, 14)}…'
          : modelName;
      bgColor = AppColors.successBackground;
      textColor = AppColors.successText;
    } else {
      label = '未加载模型';
      bgColor = const Color(0xFFFFF3CD);
      textColor = const Color(0xFF856404);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                  if (isLoaded) ...[
                    Icon(Icons.check_circle, size: 14, color: textColor),
                    const SizedBox(width: 6),
                  ],
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

// --- Language bar ---

class _LangBar extends StatelessWidget {
  const _LangBar({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  static const languages = ['英语', '中文', '日语', '韩语'];
  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LangButton(
            label: sourceLanguage,
            onTap: () => _showLangMenu(context, true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton(
            icon: const Icon(Icons.swap_horiz, size: 22),
            color: AppColors.steel,
            onPressed: onSwap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        Expanded(
          child: _LangButton(
            label: targetLanguage,
            onTap: () => _showLangMenu(context, false),
          ),
        ),
      ],
    );
  }

  void _showLangMenu(BuildContext context, bool isSource) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSource ? '源语言' : '目标语言',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...languages.map(
                (lang) => ListTile(
                  title: Text(lang),
                  trailing: lang == (isSource ? sourceLanguage : targetLanguage)
                      ? Icon(Icons.check, size: 20, color: AppColors.brandBlue)
                      : null,
                  onTap: () {
                    if (isSource)
                      onSourceChanged(lang);
                    else
                      onTargetChanged(lang);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.steel),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Input panel ---

class _InputPanel extends StatefulWidget {
  const _InputPanel({
    required this.controller,
    required this.characterCount,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int characterCount;
  final ValueChanged<String> onChanged;

  @override
  State<_InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<_InputPanel> {
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _hasFocus = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _hasFocus ? AppColors.brandBlue : AppColors.hairline,
          width: _hasFocus ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: 5,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            decoration: const InputDecoration(
              hintText: '输入要翻译的内容',
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(14, 12, 44, 28),
            ),
            onChanged: widget.onChanged,
          ),
          // Clear button — top-right corner
          if (hasText)
            Positioned(
              top: 8,
              right: 6,
              child: SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.steel,
                  padding: EdgeInsets.zero,
                  onPressed: hasText ? () => widget.controller.clear() : null,
                ),
              ),
            ),
          // Character count — bottom-right corner
          Positioned(
            bottom: 6,
            right: 12,
            child: Text(
              '${widget.characterCount}/200',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Output panel ---

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
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '译文',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: state.status == TranslatorStatus.completed
                      ? () => Clipboard.setData(
                          ClipboardData(text: state.outputText),
                        )
                      : null,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                content,
                style: textTheme.bodyLarge?.copyWith(
                  color: contentColor,
                  height: 1.6,
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
      TranslatorStatus.idle => '译文将在这里显示',
      TranslatorStatus.ready =>
        state.modelState.isReady ? '已就绪，可以翻译。' : '请先加载模型。',
      TranslatorStatus.translating => '正在翻译…',
      TranslatorStatus.completed => state.outputText,
      TranslatorStatus.cancelled => '翻译已取消。',
      TranslatorStatus.error => state.errorMessage ?? '发生错误。',
    };
  }
}

// --- Model bottom sheet ---

class _ModelSheet extends StatefulWidget {
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
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  // Rebuild when controller state changes (e.g. import completes)
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Use the latest state from a static notifier
    final modelName = widget.state.modelState.displayName ?? '未选择模型';
    final isLoaded = widget.state.modelState.isReady;
    final hasSelection = widget.state.modelState.hasSelection;
    final isDownloading = widget.state.modelDownloadState.isDownloading;
    final isLoading =
        widget.state.modelState.status == ModelLifecycleStatus.loading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
            '模型',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
                const SizedBox(height: 4),
                Text(
                  widget.state.modelState.errorMessage ??
                      (hasSelection ? '已就绪，可以加载' : '请导入或下载模型'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.state.modelState.errorMessage != null
                        ? AppColors.errorText
                        : AppColors.steel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isDownloading ? null : widget.onImport,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('导入'),
              ),
              OutlinedButton.icon(
                onPressed: isDownloading ? null : widget.onDownload,
                icon: const Icon(Icons.cloud_download, size: 18),
                label: const Text('下载'),
              ),
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: widget.onCancelDownload,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('取消下载'),
                ),
              if (hasSelection)
                FilledButton.icon(
                  onPressed: isLoading ? null : widget.onLoad,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('加载'),
                ),
              if (isLoaded)
                OutlinedButton.icon(
                  onPressed: widget.onUnload,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('卸载'),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            Text(
              widget.state.modelDownloadState.progressLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isLoaded ? Icons.check_circle : Icons.info_outline,
                size: 14,
                color: isLoaded ? AppColors.successText : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                isLoaded ? '模型已就绪' : '模型未加载',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isLoaded ? AppColors.successText : AppColors.steel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
