import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_colors.dart';
import '../../design/app_spacing.dart';
import 'macos_translator_service.dart';
import 'model_download_state.dart';
import 'model_selection_state.dart';
import 'local_model_info.dart';
import 'supported_model_info.dart';
import 'translator_channel.dart';
import 'translator_controller.dart';
import 'translator_state.dart';
import '../about/about_page.dart';

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
    _autoLoadLocalModel();
  }

  Future<void> _autoLoadLocalModel() async {
    try {
      final models = await _translatorChannel.listLocalModels();
      _controller.refreshLocalModels(models);
    } on Object {
      _controller.refreshLocalModels(const []);
    }
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

  // --- Model sheet (stays open during import) ---

  void _showModelSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _ModelSheet(
        controller: _controller,
        onImport: () => _importModelFromSheet(sheetContext),
        onDownloadSupportedModel: (_) {
          _downloadDefaultModel();
        },
        onLoad: () async {
          await _controller.loadSelectedModel();
          if (!sheetContext.mounted) return;
          if (_controller.state.modelState.isReady) {
            Navigator.pop(sheetContext);
          }
        },
        onUnload: () async {
          await _controller.unloadModel();
        },
        onCancelDownload: () {
          _cancelModelDownload();
        },
      ),
    );
  }

  Future<void> _importModelFromSheet(BuildContext sheetContext) async {
    String? path;
    if (defaultTargetPlatform == TargetPlatform.android) {
      path = await _importAndroidModel();
    } else {
      path = await _translatorChannel.importModelFile();
    }
    if (path != null && path.trim().isNotEmpty) {
      final models = await _translatorChannel.listLocalModels();
      _controller.refreshLocalModels(models, preferredPath: path);
    }
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
    _controller.beginModelDownload(
      modelId: supportedTranslatorModels.single.id,
    );
    _startDownloadPolling();
    try {
      final path = await _translatorChannel.downloadDefaultModel();
      _downloadPollTimer?.cancel();
      if (path == null || path.trim().isEmpty) {
        _controller.cancelModelDownload();
        return;
      }
      final models = await _translatorChannel.listLocalModels();
      _controller.refreshLocalModels(models, preferredPath: path);
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
        final screenWidth = MediaQuery.of(context).size.width;
        final hPadding = screenWidth < 480
            ? AppSpacing.sm
            : (screenWidth < 720 ? AppSpacing.lg : 48.0);

        return Scaffold(
          backgroundColor: AppColors.canvas,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              _buildNavBar(state),
              // Language bar + action buttons (intrinsic height)
              Padding(
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
                      onSourceChanged: _controller.updateSourceLanguage,
                      onTargetChanged: _controller.updateTargetLanguage,
                      onSwap: () {
                        _controller.updateSourceLanguage(state.targetLanguage);
                        _controller.updateTargetLanguage(state.sourceLanguage);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              // Input & Output panels. Output gets slightly more reading space.
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 9,
                        child: _InputPanel(
                          controller: _textController,
                          characterCount: _characterCount,
                          enabled: state.status != TranslatorStatus.translating,
                          onChanged: _controller.updateInput,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: _TranslateButton(
                          state: state,
                          onTranslate: () =>
                              _controller.translate(_textController.text),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(flex: 11, child: _OutputPanel(state: state)),
                    ],
                  ),
                ),
              ),
              // Disclaimer
              Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md + MediaQuery.of(context).padding.bottom,
                ),
                child: Center(
                  child: Text(
                    '结果由 AI 生成，仅供参考',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ),
            ],
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

    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final capsuleMaxWidth = screenWidth < 380
        ? 124.0
        : (screenWidth < 480 ? 156.0 : 220.0);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8 + topPadding, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'AI离线翻译',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.steel,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '了解更多',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: capsuleMaxWidth),
            child: GestureDetector(
              onTap: _showModelSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Translate button ---

class _TranslateButton extends StatelessWidget {
  const _TranslateButton({required this.state, required this.onTranslate});
  final TranslatorState state;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final isTranslating = state.status == TranslatorStatus.translating;
    final isDisabled = !isTranslating && !state.canTranslate;

    if (isTranslating) {
      // Keep dark active look but block taps via AbsorbPointer
      return AbsorbPointer(
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          onPressed: () {}, // non-null so active style applies
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onPrimary,
                ),
              ),
              SizedBox(width: 8),
              Text('翻译中'),
            ],
          ),
        ),
      );
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        disabledBackgroundColor: const Color(0xFFE5E7EB),
        disabledForegroundColor: const Color(0xFFA8AAB2),
      ),
      onPressed: isDisabled ? null : onTranslate,
      child: const Text('翻译'),
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

  static const languages = [
    _LanguageOption('zh', '中文'),
    _LanguageOption('en', '英语'),
    _LanguageOption('fr', '法语'),
    _LanguageOption('pt', '葡萄牙语'),
    _LanguageOption('es', '西班牙语'),
    _LanguageOption('ja', '日语'),
    _LanguageOption('tr', '土耳其语'),
    _LanguageOption('ru', '俄语'),
    _LanguageOption('ar', '阿拉伯语'),
    _LanguageOption('ko', '韩语'),
    _LanguageOption('th', '泰语'),
    _LanguageOption('it', '意大利语'),
    _LanguageOption('de', '德语'),
    _LanguageOption('vi', '越南语'),
    _LanguageOption('ms', '马来语'),
    _LanguageOption('id', '印尼语'),
    _LanguageOption('zh-Hant', '繁体中文'),
    _LanguageOption('pl', '波兰语'),
    _LanguageOption('cs', '捷克语'),
    _LanguageOption('nl', '荷兰语'),
    _LanguageOption('my', '缅甸语'),
    _LanguageOption('fa', '波斯语'),
    _LanguageOption('ur', '乌尔都语'),
    _LanguageOption('mr', '马拉地语'),
    _LanguageOption('he', '希伯来语'),
    _LanguageOption('bn', '孟加拉语'),
    _LanguageOption('ta', '泰米尔语'),
    _LanguageOption('uk', '乌克兰语'),
    _LanguageOption('bo', '藏语'),
    _LanguageOption('kk', '哈萨克语'),
    _LanguageOption('mn', '蒙古语'),
    _LanguageOption('ug', '维吾尔语'),
  ];
  final String sourceLanguage;
  final String targetLanguage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onSwap;

  String _labelForLanguage(String name) {
    final index = languages.indexWhere((l) => l.name == name);
    return index != -1 ? languages[index].menuLabel : name;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LangButton(
            label: _labelForLanguage(sourceLanguage),
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
            label: _labelForLanguage(targetLanguage),
            onTap: () => _showLangMenu(context, false),
          ),
        ),
      ],
    );
  }

  void _showLangMenu(BuildContext context, bool isSource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.75,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
            child: Column(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('language_menu_scroll'),
                    child: Column(
                      children: languages
                          .map(
                            (language) => ListTile(
                              title: Text(language.menuLabel),
                              trailing:
                                  language.name ==
                                      (isSource
                                          ? sourceLanguage
                                          : targetLanguage)
                                  ? Icon(
                                      Icons.check,
                                      size: 20,
                                      color: AppColors.brandBlue,
                                    )
                                  : null,
                              onTap: () {
                                if (isSource) {
                                  onSourceChanged(language.name);
                                } else {
                                  onTargetChanged(language.name);
                                }
                                Navigator.pop(ctx);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption(this.code, this.name);

  final String code;
  final String name;

  String get menuLabel => '$name ($code)';
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
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int characterCount;
  final bool enabled;
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
      key: const ValueKey('input_panel'),
      constraints: const BoxConstraints.expand(),
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
            expands: true,
            minLines: null,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            enabled: widget.enabled,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: '输入要翻译的内容',
              hintStyle: TextStyle(
                color: AppColors.muted.withValues(alpha: 0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(14, 12, 44, 28),
            ),
            inputFormatters: const [_MeaningfulCharacterLimitFormatter(200)],
            onChanged: widget.onChanged,
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
          // Clear button — top-right corner (after TextField in Stack for z-order)
          if (hasText && widget.enabled)
            Positioned(
              top: 8,
              right: 6,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.steel,
                    padding: EdgeInsets.zero,
                    onPressed: () => widget.controller.clear(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MeaningfulCharacterLimitFormatter extends TextInputFormatter {
  const _MeaningfulCharacterLimitFormatter(this.maxLength);

  final int maxLength;

  static final RegExp _countedCharacterPattern = RegExp(
    r'[\w\u4e00-\u9fff\u3400-\u4dbf]',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_countMeaningfulCharacters(newValue.text) <= maxLength) {
      return newValue;
    }

    final limitedText = _limitMeaningfulCharacters(newValue.text);
    return TextEditingValue(
      text: limitedText,
      selection: TextSelection.collapsed(offset: limitedText.length),
    );
  }

  static int _countMeaningfulCharacters(String text) {
    return _countedCharacterPattern.allMatches(text).length;
  }

  String _limitMeaningfulCharacters(String text) {
    final buffer = StringBuffer();
    var count = 0;

    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final isCounted = _countedCharacterPattern.hasMatch(character);
      if (isCounted) {
        if (count >= maxLength) continue;
        count += 1;
      }
      buffer.write(character);
    }

    return buffer.toString();
  }
}

// --- Output panel ---

class _OutputPanel extends StatefulWidget {
  const _OutputPanel({required this.state});
  final TranslatorState state;

  @override
  State<_OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends State<_OutputPanel> {
  String _displayedText = '';
  Timer? _typewriterTimer;
  int _charIndex = 0;
  String _lastSourceText = '';
  TranslatorStatus? _lastStatus;

  static const int _charDelayMs = 40;

  @override
  void didUpdateWidget(covariant _OutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.state.status;
    final outputText = widget.state.outputText;

    // Reset when a new translation starts
    if (status == TranslatorStatus.translating &&
        _lastStatus != TranslatorStatus.translating) {
      _displayedText = '';
      _charIndex = 0;
      _lastSourceText = outputText;
      _stopTypewriter();
    }

    // Typewriter during translating
    if (status == TranslatorStatus.translating && outputText.isNotEmpty) {
      _lastSourceText = outputText;
      _ensureTypewriter();
    }

    // On completed, show everything immediately
    if (status == TranslatorStatus.completed &&
        _lastStatus != TranslatorStatus.completed) {
      _stopTypewriter();
      _displayedText = outputText;
      _charIndex = outputText.length;
    }

    // Reset on idle/error/cancelled/ready
    if (status != TranslatorStatus.translating &&
        status != TranslatorStatus.completed) {
      _stopTypewriter();
      if (_lastStatus == TranslatorStatus.translating ||
          _lastStatus == TranslatorStatus.completed) {
        _displayedText = '';
        _charIndex = 0;
      }
    }

    _lastStatus = status;
    if (mounted) setState(() {});
  }

  void _ensureTypewriter() {
    if (_typewriterTimer != null) return;
    void tick() {
      if (!mounted) {
        _stopTypewriter();
        return;
      }
      if (_charIndex < _lastSourceText.length) {
        _charIndex++;
        setState(() {
          _displayedText = _lastSourceText.substring(0, _charIndex);
        });
        _typewriterTimer = Timer(
          const Duration(milliseconds: _charDelayMs),
          tick,
        );
      } else {
        _typewriterTimer = null;
      }
    }

    tick();
  }

  void _stopTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;
  }

  @override
  void dispose() {
    _stopTypewriter();
    super.dispose();
  }

  bool get _isPlaceholder {
    return switch (widget.state.status) {
      TranslatorStatus.idle => true,
      TranslatorStatus.ready => true,
      TranslatorStatus.cancelled => true,
      _ => false,
    };
  }

  String get _content {
    final status = widget.state.status;
    if (status == TranslatorStatus.translating) {
      return _displayedText.isEmpty ? '' : _displayedText;
    }
    if (status == TranslatorStatus.completed) {
      return _displayedText;
    }
    return switch (status) {
      TranslatorStatus.idle => '译文将在这里显示',
      TranslatorStatus.ready =>
        widget.state.modelState.isReady ? '已就绪，可以翻译。' : '请先加载模型。',
      TranslatorStatus.cancelled => '翻译已取消。',
      TranslatorStatus.error => widget.state.errorMessage ?? '发生错误。',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = _content;
    final contentColor = widget.state.status == TranslatorStatus.error
        ? AppColors.errorText
        : AppColors.ink;
    final isTranslating = widget.state.status == TranslatorStatus.translating;

    return Container(
      key: const ValueKey('output_panel'),
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
              if (isTranslating)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '翻译中',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              if (widget.state.status == TranslatorStatus.completed)
                SizedBox(
                  height: 28,
                  child: IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.state.outputText),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制译文'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.only(
                            bottom: 80,
                            left: 40,
                            right: 40,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    color: AppColors.steel,
                    padding: EdgeInsets.zero,
                    tooltip: '复制',
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
                  color: _isPlaceholder
                      ? AppColors.muted.withValues(alpha: 0.6)
                      : contentColor,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSheet extends StatefulWidget {
  const _ModelSheet({
    required this.controller,
    required this.onImport,
    required this.onDownloadSupportedModel,
    required this.onLoad,
    required this.onUnload,
    required this.onCancelDownload,
  });

  final TranslatorController controller;
  final VoidCallback onImport;
  final void Function(SupportedModelInfo) onDownloadSupportedModel;
  final Future<void> Function() onLoad;
  final Future<void> Function() onUnload;
  final VoidCallback onCancelDownload;

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant _ModelSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    if (mb >= 100) return '\${mb.toStringAsFixed(0)} MB';
    return '\${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final modelName = state.modelState.displayName ?? '未选择模型';
    final isLoaded = state.modelState.isReady;
    final hasSelection = state.modelState.hasSelection;
    final isDownloading = state.modelDownloadState.isDownloading;
    final isLoading = state.modelState.status == ModelLifecycleStatus.loading;

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
                  state.modelState.errorMessage ??
                      (hasSelection ? '已就绪，可以加载' : '请导入或下载模型'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: state.modelState.errorMessage != null
                        ? AppColors.errorText
                        : AppColors.steel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...state.modelState.supportedModels.map((supported) {
            LocalModelInfo? local;
            for (final model in state.modelState.availableModels) {
              if (model.name == supported.filename) {
                local = model;
                break;
              }
            }
            final isDownloaded = local != null;
            final isSelected = local?.path == state.modelState.selectedPath;
            final isLoadedModel = local?.path == state.modelState.loadedPath;
            final isRowDownloading =
                state.modelState.downloadingModelId == supported.id &&
                isDownloading;
            final subtitle = isDownloaded
                ? '${_formatBytes(local.sizeBytes)}${isLoadedModel ? ' · 已加载' : ''}'
                : '${supported.expectedSizeLabel} · 未下载';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isDownloaded && !isDownloading && !isLoading
                    ? () => widget.controller.selectLocalModel(local!)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceSoft
                        : AppColors.canvas,
                    border: Border.all(
                      color: isSelected ? AppColors.ink : AppColors.hairline,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supported.displayName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isLoadedModel
                                        ? AppColors.successText
                                        : AppColors.steel,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isRowDownloading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (isDownloaded)
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 24,
                          color: isSelected ? AppColors.ink : AppColors.steel,
                        )
                      else
                        IconButton(
                          tooltip: '下载模型',
                          onPressed: (isDownloading || isLoading)
                              ? null
                              : () =>
                                    widget.onDownloadSupportedModel(supported),
                          icon: const Icon(Icons.download, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: (isDownloading || isLoading)
                    ? null
                    : widget.onImport,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('导入'),
              ),
              if (isDownloading)
                OutlinedButton.icon(
                  onPressed: widget.onCancelDownload,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('取消下载'),
                ),
              if (hasSelection && !isLoaded)
                FilledButton.icon(
                  onPressed: isLoading ? null : () => widget.onLoad(),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('加载'),
                ),
              if (isLoaded)
                OutlinedButton.icon(
                  onPressed: isLoading ? null : () => widget.onUnload(),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('卸载'),
                ),
            ],
          ),
          // Download progress or completion feedback
          if (isDownloading) ...[
            const SizedBox(height: 10),
            Text(
              state.modelDownloadState.progressLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ],
          if (state.modelDownloadState.status ==
                  ModelDownloadStatus.completed &&
              !isDownloading) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.successText,
                ),
                const SizedBox(width: 6),
                Text(
                  '模型已下载，请点击「加载」',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.successText),
                ),
              ],
            ),
          ],
          if (state.modelDownloadState.status ==
              ModelDownloadStatus.cancelled) ...[
            const SizedBox(height: 10),
            Text(
              '下载已取消',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.steel),
            ),
          ],
          if (state.modelDownloadState.status ==
              ModelDownloadStatus.failed) ...[
            const SizedBox(height: 10),
            Text(
              state.modelDownloadState.message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.errorText),
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
