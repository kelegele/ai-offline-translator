# Flutter App Bootstrap Design

## Context

This repository is preparing an offline translation app. The current validated technical direction is Flutter UI with a native `llama.cpp` inference layer. The first app milestone should establish a maintainable Flutter project boundary without pulling native inference complexity into the initial scaffold.

The model and runtime direction remain:

- MVP model: `Hy-MT1.5-1.8B-STQ1_0.gguf`
- Runtime dependency: `third_party/llama.cpp` pinned to PR #22836
- Target product path: Apple Silicon / ARM mobile first
- Development validation path: macOS first, with Android and iOS project directories generated

UI work must follow `DESIGN.md`, which defines the MiniMax-inspired visual system for colors, typography, spacing, rounded corners, inputs, buttons, and card surfaces.

## Decisions

- Use option C: architecture skeleton first.
- Use option D: generate Android, iOS, and macOS project support, while only requiring macOS validation for the first pass.
- Use package name `ai_offline_translator`.
- Create the Flutter project under `flutter_app/`.
- Do not connect real `llama.cpp` inference in the first scaffold.
- Provide a mock translation service so the UI and controller flow can be exercised without native bindings.

## Project Shape

The initial Flutter tree should keep feature code grouped by the translator domain:

```text
flutter_app/
├─ pubspec.yaml
├─ lib/
│  ├─ main.dart
│  ├─ app.dart
│  ├─ design/
│  │  ├─ app_colors.dart
│  │  ├─ app_spacing.dart
│  │  └─ app_theme.dart
│  └─ features/
│     └─ translator/
│        ├─ translator_channel.dart
│        ├─ translator_controller.dart
│        ├─ translator_page.dart
│        ├─ translator_service.dart
│        └─ translator_state.dart
└─ test/
   └─ features/
      └─ translator/
         ├─ translator_controller_test.dart
         └─ translator_service_test.dart
```

Generated platform directories should include Android, iOS, and macOS. Linux, Windows, and web are not required for the first scaffold unless Flutter generates them by default and excluding them adds unnecessary churn.

## Architecture

`TranslatorPage` owns presentation only. It renders input text, source and target language controls, output text, loading state, cancel affordance, and model/runtime status.

`TranslatorController` owns UI state transitions. It accepts user actions, calls the service, exposes immutable `TranslatorState`, and keeps error and cancellation behavior explicit.

`TranslatorService` is the app-facing translation API. The initial implementation returns a deterministic mock translation, enough to verify flow and tests.

`TranslatorChannel` defines the future native bridge surface. It should not call platform code yet. Its methods should mirror the intended native responsibilities:

- `loadModel`
- `translate`
- `cancel`
- `unloadModel`
- `getModelStatus`

This keeps the Dart layer ready for native inference without blocking the first scaffold on C++, Kotlin, Swift, CMake, or platform packaging.

## UI Direction

The first screen is the translation workspace, not a landing page.

The layout should be a calm tool surface:

- App title and compact runtime status at the top.
- Source language and target language controls.
- Source text input area.
- Primary translate action using the black pill button style from `DESIGN.md`.
- Output panel with loading, success, error, and empty states.
- Secondary controls for cancel and clear.

The visual system should use `DESIGN.md` tokens where practical. If `DM Sans` is not installed or bundled in the first pass, use Flutter platform fonts while preserving the relative hierarchy, spacing, and component proportions.

## Error Handling

The skeleton should model these states even with mock inference:

- Idle with no input.
- Ready with input.
- Translating.
- Completed.
- Cancelled.
- Error.

Empty input should not call the service. Service errors should be surfaced as readable UI errors without crashing the app.

## Testing

Initial tests should cover the Dart behavior that can be validated without native bindings:

- Mock service returns deterministic output.
- Controller rejects empty input.
- Controller transitions through translating and completed states.
- Controller surfaces service errors.

Flutter analyzer should be part of the first validation if the SDK is available. The current shell does not have `flutter` on `PATH`, so commands should use `/Users/fh/Projects/Flutter/flutter/bin/flutter` unless the environment changes.

## Non-Goals

- No real `llama.cpp` native integration in this scaffold.
- No model packaging inside the Flutter app.
- No Android NDK or iOS native build pipeline yet.
- No multi-model management.
- No chat interface.
- No marketing homepage.

## Open Follow-Up

After this scaffold is validated, the next design step should decide how the native bridge will be implemented per platform and how the local model file is discovered during development.
