# Flutter App Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Flutter app skeleton under `flutter_app/` with Android, iOS, and macOS platform support, a MiniMax-inspired design token layer, a translator feature architecture, mock translation behavior, and focused Dart tests.

**Architecture:** The scaffold creates a standard Flutter project and keeps app code split into presentation, controller, service, channel boundary, and immutable state files. The first implementation uses a deterministic mock translation service and does not connect native `llama.cpp`; `TranslatorChannel` only defines the future bridge shape.

**Tech Stack:** Flutter 3.35.5 at `/Users/fh/Projects/Flutter/flutter/bin/flutter`, Dart 3.9.2, Flutter `material` widgets, `flutter_test`, Android/iOS/macOS generated platform directories.

---

## File Structure

- Create generated Flutter project: `flutter_app/`
- Create/replace: `flutter_app/lib/main.dart` as a minimal app entrypoint.
- Create: `flutter_app/lib/app.dart` for `MaterialApp` configuration.
- Create: `flutter_app/lib/design/app_colors.dart` for color constants derived from `DESIGN.md`.
- Create: `flutter_app/lib/design/app_spacing.dart` for spacing and radius constants derived from `DESIGN.md`.
- Create: `flutter_app/lib/design/app_theme.dart` for Flutter `ThemeData`.
- Create: `flutter_app/lib/features/translator/translator_state.dart` for immutable translator state and status enum.
- Create: `flutter_app/lib/features/translator/translator_service.dart` for deterministic mock translation and service contract.
- Create: `flutter_app/lib/features/translator/translator_channel.dart` for future native bridge API shape.
- Create: `flutter_app/lib/features/translator/translator_controller.dart` for state transitions and translation orchestration.
- Create: `flutter_app/lib/features/translator/translator_page.dart` for the first tool-style translation workspace.
- Create: `flutter_app/test/features/translator/translator_service_test.dart` for service behavior.
- Create: `flutter_app/test/features/translator/translator_controller_test.dart` for controller states and errors.
- Modify generated files only as needed to remove default counter app behavior.

## Task 1: Generate Flutter Project

**Files:**
- Create: `flutter_app/`
- Modify: `.gitignore`

- [ ] **Step 1: Verify Flutter SDK**

Run:

```bash
/Users/fh/Projects/Flutter/flutter/bin/flutter --version
```

Expected: command exits 0 and prints Flutter 3.35.5 or another installed Flutter version.

- [ ] **Step 2: Generate the project**

Run from repository root:

```bash
/Users/fh/Projects/Flutter/flutter/bin/flutter create \
  --project-name ai_offline_translator \
  --org com.kelegele \
  --platforms android,ios,macos \
  flutter_app
```

Expected: `flutter_app/pubspec.yaml`, `flutter_app/lib/main.dart`, `flutter_app/android/`, `flutter_app/ios/`, and `flutter_app/macos/` exist.

- [ ] **Step 3: Remove generated platforms outside scope if present**

Run:

```bash
find flutter_app -maxdepth 1 -type d \( -name linux -o -name windows -o -name web \) -print
```

Expected: no output. If any of those directories exist, remove only those generated directories with:

```bash
rm -rf flutter_app/linux flutter_app/windows flutter_app/web
```

- [ ] **Step 4: Ensure generated build noise is ignored**

Inspect `.gitignore`. It must already include Flutter build output patterns such as:

```gitignore
.dart_tool/
build/
**/ios/Pods/
**/macos/Flutter/ephemeral/
```

If the generated project introduces unignored build/cache files in `git status --short`, add only those cache/build patterns to `.gitignore`.

- [ ] **Step 5: Run baseline Flutter commands**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter pub get
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test
```

Expected: dependency resolution succeeds and the generated sample test passes.

- [ ] **Step 6: Commit**

Run:

```bash
git add .gitignore flutter_app
git commit -m "Create Flutter app scaffold"
```

Expected: commit succeeds with generated Flutter scaffold.

## Task 2: Add Design Tokens and App Shell

**Files:**
- Replace: `flutter_app/lib/main.dart`
- Create: `flutter_app/lib/app.dart`
- Create: `flutter_app/lib/design/app_colors.dart`
- Create: `flutter_app/lib/design/app_spacing.dart`
- Create: `flutter_app/lib/design/app_theme.dart`
- Modify: `flutter_app/test/widget_test.dart`

- [ ] **Step 1: Replace generated app test with a failing shell test**

Write `flutter_app/test/widget_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders translator app shell', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI Offline Translator'), findsOneWidget);
    expect(find.text('Local model ready'), findsOneWidget);
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because `app.dart` and `OfflineTranslatorApp` do not exist yet.

- [ ] **Step 2: Add color tokens**

Create `flutter_app/lib/design/app_colors.dart` exactly as:

```dart
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0A0A0A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F8FA);
  static const Color surfaceSoft = Color(0xFFF2F3F5);
  static const Color hairline = Color(0xFFE5E7EB);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color slate = Color(0xFF45515E);
  static const Color steel = Color(0xFF5F5F5F);
  static const Color muted = Color(0xFFA8AAB2);
  static const Color brandBlue = Color(0xFF1456F0);
  static const Color brandBlueDeep = Color(0xFF1D4ED8);
  static const Color successBackground = Color(0xFFE8FFEA);
  static const Color successText = Color(0xFF1BA673);
  static const Color errorText = Color(0xFFD45656);
}
```

- [ ] **Step 3: Add spacing and radius tokens**

Create `flutter_app/lib/design/app_spacing.dart` exactly as:

```dart
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 64;
}

class AppRadius {
  const AppRadius._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;
}
```

- [ ] **Step 4: Add theme**

Create `flutter_app/lib/design/app_theme.dart` exactly as:

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.canvas,
      ),
      useMaterial3: true,
      fontFamily: 'DM Sans',
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandBlueDeep, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Add app shell**

Create `flutter_app/lib/app.dart` exactly as:

```dart
import 'package:flutter/material.dart';

import 'design/app_theme.dart';
import 'features/translator/translator_page.dart';

class OfflineTranslatorApp extends StatelessWidget {
  const OfflineTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Offline Translator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const TranslatorPage(),
    );
  }
}
```

Replace `flutter_app/lib/main.dart` exactly as:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const OfflineTranslatorApp());
}
```

For this task only, if `TranslatorPage` does not exist yet, create `flutter_app/lib/features/translator/translator_page.dart` exactly as a temporary minimal page:

```dart
import 'package:flutter/material.dart';

class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI Offline Translator'),
            Text('Local model ready'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run test and analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/widget_test.dart
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: both commands pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add flutter_app/lib flutter_app/test
git commit -m "Add Flutter app shell"
```

Expected: commit succeeds.

## Task 3: Add Translator State, Service, Channel, and Controller

**Files:**
- Create: `flutter_app/lib/features/translator/translator_state.dart`
- Create: `flutter_app/lib/features/translator/translator_service.dart`
- Create: `flutter_app/lib/features/translator/translator_channel.dart`
- Create: `flutter_app/lib/features/translator/translator_controller.dart`
- Create: `flutter_app/test/features/translator/translator_service_test.dart`
- Create: `flutter_app/test/features/translator/translator_controller_test.dart`

- [ ] **Step 1: Write failing service test**

Create `flutter_app/test/features/translator/translator_service_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock service returns deterministic Chinese translation', () async {
    const service = MockTranslatorService();

    final result = await service.translate(
      text: 'Hello',
      sourceLanguage: 'English',
      targetLanguage: 'Chinese',
    );

    expect(result, '你好');
  });

  test('mock service echoes unsupported text with target language', () async {
    const service = MockTranslatorService();

    final result = await service.translate(
      text: 'Good morning',
      sourceLanguage: 'English',
      targetLanguage: 'Chinese',
    );

    expect(result, '[Chinese] Good morning');
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_service_test.dart
```

Expected: FAIL because `translator_service.dart` does not exist yet.

- [ ] **Step 2: Add service implementation**

Create `flutter_app/lib/features/translator/translator_service.dart` exactly as:

```dart
abstract interface class TranslatorService {
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

class MockTranslatorService implements TranslatorService {
  const MockTranslatorService();

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final normalized = text.trim().toLowerCase();
    if (sourceLanguage == 'English' && targetLanguage == 'Chinese' && normalized == 'hello') {
      return '你好';
    }

    return '[$targetLanguage] ${text.trim()}';
  }
}
```

Run the service test again. Expected: PASS.

- [ ] **Step 3: Write failing controller test**

Create `flutter_app/test/features/translator/translator_controller_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/features/translator/translator_controller.dart';
import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:ai_offline_translator/features/translator/translator_state.dart';
import 'package:flutter_test/flutter_test.dart';

class ThrowingTranslatorService implements TranslatorService {
  const ThrowingTranslatorService();

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    throw StateError('native bridge unavailable');
  }
}

void main() {
  test('initial state is idle with default languages', () {
    final controller = TranslatorController(service: const MockTranslatorService());

    expect(controller.state.status, TranslatorStatus.idle);
    expect(controller.state.sourceLanguage, 'English');
    expect(controller.state.targetLanguage, 'Chinese');
  });

  test('empty input is rejected without calling translation', () async {
    final controller = TranslatorController(service: const MockTranslatorService());

    await controller.translate('   ');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, 'Enter text to translate.');
  });

  test('successful translation updates output', () async {
    final controller = TranslatorController(service: const MockTranslatorService());

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.completed);
    expect(controller.state.inputText, 'Hello');
    expect(controller.state.outputText, '你好');
  });

  test('service errors are surfaced', () async {
    final controller = TranslatorController(service: const ThrowingTranslatorService());

    await controller.translate('Hello');

    expect(controller.state.status, TranslatorStatus.error);
    expect(controller.state.errorMessage, 'native bridge unavailable');
  });

  test('cancel sets cancelled state', () {
    final controller = TranslatorController(service: const MockTranslatorService());

    controller.cancel();

    expect(controller.state.status, TranslatorStatus.cancelled);
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/features/translator/translator_controller_test.dart
```

Expected: FAIL because state and controller files do not exist yet.

- [ ] **Step 4: Add state model**

Create `flutter_app/lib/features/translator/translator_state.dart` exactly as:

```dart
enum TranslatorStatus {
  idle,
  ready,
  translating,
  completed,
  cancelled,
  error,
}

class TranslatorState {
  const TranslatorState({
    this.status = TranslatorStatus.idle,
    this.inputText = '',
    this.outputText = '',
    this.sourceLanguage = 'English',
    this.targetLanguage = 'Chinese',
    this.errorMessage,
  });

  final TranslatorStatus status;
  final String inputText;
  final String outputText;
  final String sourceLanguage;
  final String targetLanguage;
  final String? errorMessage;

  bool get canTranslate => inputText.trim().isNotEmpty && status != TranslatorStatus.translating;

  TranslatorState copyWith({
    TranslatorStatus? status,
    String? inputText,
    String? outputText,
    String? sourceLanguage,
    String? targetLanguage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TranslatorState(
      status: status ?? this.status,
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
```

- [ ] **Step 5: Add native channel boundary**

Create `flutter_app/lib/features/translator/translator_channel.dart` exactly as:

```dart
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
```

- [ ] **Step 6: Add controller**

Create `flutter_app/lib/features/translator/translator_controller.dart` exactly as:

```dart
import 'package:flutter/foundation.dart';

import 'translator_service.dart';
import 'translator_state.dart';

class TranslatorController extends ChangeNotifier {
  TranslatorController({required TranslatorService service}) : _service = service;

  final TranslatorService _service;

  TranslatorState _state = const TranslatorState();

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

  Future<void> translate(String text) async {
    final trimmed = text.trim();
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

    try {
      final output = await _service.translate(
        text: trimmed,
        sourceLanguage: _state.sourceLanguage,
        targetLanguage: _state.targetLanguage,
      );
      _state = _state.copyWith(
        status: TranslatorStatus.completed,
        outputText: output,
        clearError: true,
      );
    } on Object catch (error) {
      _state = _state.copyWith(
        status: TranslatorStatus.error,
        errorMessage: error is StateError ? error.message : error.toString(),
      );
    }
    notifyListeners();
  }

  void cancel() {
    _state = _state.copyWith(status: TranslatorStatus.cancelled);
    notifyListeners();
  }

  void clear() {
    _state = const TranslatorState();
    notifyListeners();
  }
}
```

Run service and controller tests. Expected: PASS.

- [ ] **Step 7: Run analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add flutter_app/lib/features/translator flutter_app/test/features/translator
git commit -m "Add translator feature model"
```

Expected: commit succeeds.

## Task 4: Build Translator Workspace UI

**Files:**
- Replace: `flutter_app/lib/features/translator/translator_page.dart`
- Modify: `flutter_app/test/widget_test.dart`

- [ ] **Step 1: Write failing widget expectations**

Replace `flutter_app/test/widget_test.dart` exactly as:

```dart
import 'package:ai_offline_translator/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders translator workspace controls', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    expect(find.text('AI Offline Translator'), findsOneWidget);
    expect(find.text('Local model ready'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Chinese'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('translates hello with mock service', (tester) async {
    await tester.pumpWidget(const OfflineTranslatorApp());

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.text('Translate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('你好'), findsOneWidget);
  });
}
```

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/widget_test.dart
```

Expected: FAIL because the temporary page does not render the full workspace.

- [ ] **Step 2: Implement translator workspace page**

Replace `flutter_app/lib/features/translator/translator_page.dart` exactly as:

```dart
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
                            onPressed: state.status == TranslatorStatus.translating ? _controller.cancel : null,
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
      value: value,
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
    final contentColor = state.status == TranslatorStatus.error ? AppColors.errorText : AppColors.ink;

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
```

- [ ] **Step 3: Run widget tests**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run full test and analyzer**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add flutter_app/lib/features/translator/translator_page.dart flutter_app/test/widget_test.dart
git commit -m "Build translator workspace UI"
```

Expected: commit succeeds.

## Task 5: Final Validation and Documentation Touch-Up

**Files:**
- Modify: `README.md`
- Optional modify: `docs/flutter_mobile_architecture.md`

- [ ] **Step 1: Write README update**

Add a short Flutter section to `README.md` after the local directory convention block:

```markdown
## Flutter App

The Flutter app skeleton lives in `flutter_app/`.

Current scope:

- Android, iOS, and macOS project directories are generated.
- The first validated runtime target is macOS.
- The translator feature currently uses a deterministic mock service.
- Native `llama.cpp` integration is intentionally deferred behind `TranslatorChannel`.

Useful commands:

```bash
cd flutter_app
/Users/fh/Projects/Flutter/flutter/bin/flutter pub get
/Users/fh/Projects/Flutter/flutter/bin/flutter test
/Users/fh/Projects/Flutter/flutter/bin/flutter analyze
/Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```
```

- [ ] **Step 2: Run final validation**

Run:

```bash
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter test
cd flutter_app && /Users/fh/Projects/Flutter/flutter/bin/flutter analyze
```

Expected: PASS.

If macOS desktop support is available, run:

```bash
cd flutter_app && timeout 60s /Users/fh/Projects/Flutter/flutter/bin/flutter run -d macos
```

Expected: app builds and starts, or exits due to timeout after confirming build progress. Do not leave a long-running Flutter process active.

- [ ] **Step 3: Confirm git status**

Run:

```bash
git status --short --branch
```

Expected: only intended README/doc changes are unstaged before commit; after commit, branch is clean.

- [ ] **Step 4: Commit**

Run:

```bash
git add README.md docs/flutter_mobile_architecture.md
git commit -m "Document Flutter app scaffold"
```

Expected: commit succeeds if files changed. If `docs/flutter_mobile_architecture.md` was not changed, omit it from `git add`.
