# Offline Translator App Implementation Design

## Context

This project is building an offline translation app around `Hy-MT1.5-1.8B-STQ1_0.gguf` and a `llama.cpp` runtime pinned to PR #22836. We already have a Flutter app skeleton with a translator workspace UI, a controller, a mock service, and tests. The next design must define the real product and technical implementation path using the reverse-engineering results from `models/AngelSlim/Hy-MT-demo-apk-technical-report.md`.

The APK report shows a proven Android demo pattern:

- model files are not bundled into the app binary
- model files are loaded from app-private storage
- the business layer talks to an inference engine abstraction
- native inference is implemented through a custom bridge on top of `llama.cpp`
- prompt formatting is explicit and translation-oriented
- cancellation and generation states are first-class runtime concerns

This project should adopt the useful structural lessons without copying the Android app literally.

## Product Goal

Build a practical offline translation app with a Flutter UI and a native translation engine. The first real inference milestone should work on macOS, while preserving an architecture that can later support Android and iOS without rewriting the application model.

The product is a translation tool, not a chat app. The first useful version should focus on loading a local model file, translating single text segments, showing runtime state, and allowing cancellation.

## Confirmed Decisions

- Scope covers both product behavior and technical implementation.
- Model acquisition strategy is phased:
  - first: manual import or manual selection of a local model file
  - later: in-app download to app-private storage
- First real inference target is `macOS`.
- Flutter remains the cross-platform UI layer.
- Native inference should converge toward a shared `translator_engine` core with thin platform-specific bridges.
- UI defaults should remain Chinese-first.

## Recommended Implementation Strategy

Use a phased delivery plan with a shared engine direction:

- delivery sequencing follows a staged approach
- architecture follows a shared native core approach

In practice this means:

1. keep Flutter responsible for screens, state, user actions, and model-management UX
2. introduce a real `TranslatorService` implementation backed by a native bridge on macOS
3. define a unified `translator_engine` abstraction now, even if only macOS is implemented first
4. keep Android and iOS bridge contracts aligned with the macOS bridge from the beginning

This balances short-term delivery with long-term maintainability.

## Product Design

### Primary Experience

The first screen remains the translation workspace. It should evolve from the current mock UI into a real offline translator console with these sections:

- model status header
- model file selection and load controls
- source and target language controls
- source text input
- translation action row with translate, cancel, and clear
- translation output panel
- runtime status and error messaging

The app should clearly separate model lifecycle from translation lifecycle. Users should understand whether the current issue is “no model selected”, “model loading”, “ready”, “translating”, “cancelled”, or “error”.

### Phase 1 User Flow

1. User opens app.
2. App shows no model loaded.
3. User selects a local GGUF file.
4. App loads the model.
5. User enters text.
6. User taps translate.
7. App streams or progressively updates output.
8. User may cancel.
9. User may clear and translate again.

### Phase 2 User Flow

After the local-file version is stable, add an in-app model download flow inspired by the APK:

- model catalog page
- download progress
- app-private model storage
- downloaded model list
- current model selection

This should remain a second-phase concern and not block the first macOS real inference milestone.

## Technical Architecture

### Layering

The app should be organized into these layers:

- Flutter presentation layer
- Dart application/service layer
- platform bridge layer
- shared native translation engine
- `llama.cpp` runtime and model file

### Dart Layer

The Dart side should expose a clear, app-oriented surface:

- `TranslatorController`
- `TranslatorState`
- `TranslatorService`
- `TranslatorChannel`
- `ModelCatalog` or `ModelRepository`
- `ModelSelectionState`

`TranslatorController` should continue to own UI state transitions. `TranslatorService` should stop being a mock-only abstraction and become the stable app-facing contract for:

- loading a model
- unloading a model
- querying status
- sending translation requests
- cancelling in-flight work

`TranslatorChannel` should be treated as transport glue, not business logic.

### Native Engine Abstraction

The APK report suggests the right shape: an `InferenceEngine`-style boundary.

For this project, the cross-platform native abstraction should become `translator_engine`, responsible for:

- initialization and shutdown
- model loading from a file path
- prompt preparation
- translation execution
- next-token generation or streaming callbacks
- cancellation
- cleanup between requests
- reporting runtime state and error codes

The Flutter layer should never call `llama.cpp` directly.

### macOS First Bridge

The first real implementation should target macOS with:

- Flutter macOS plugin or Runner-integrated channel handler in Swift
- ObjC++ or C++ bridge that calls into `translator_engine`
- `translator_engine` linking against the pinned `llama.cpp` / `ggml` stack

On macOS, do not imitate Android’s runtime `.so` discovery model. Instead, use a fixed Apple-appropriate packaging strategy such as:

- a bundled `.dylib`
- a bundled framework
- or direct linking into the app target

The design should prefer the simplest packaging route that works on the current Apple Silicon development machine.

## Model Strategy

### Supported Model

The first real implementation supports one model only:

- `Hy-MT1.5-1.8B-STQ1_0.gguf`

No multi-model routing is needed in the first milestone.

### Model File Protocol

Across all platforms, keep the same conceptual contract:

- the app obtains a local GGUF file path
- the native engine loads from that file path

This matches both the APK findings and the current repository direction.

### Storage Strategy

Phase 1:

- user chooses a local file manually
- app stores the chosen path or a security-scoped reference appropriate to the platform

Phase 2:

- app downloads the model into app-private storage
- app manages model existence, selection, and reuse

The APK uses app-private `files/models/`. We should mirror the same principle, but with platform-appropriate paths:

- Android: app-private files directory
- macOS: Application Support or another app-private container path
- iOS: Application Support inside the app sandbox

## Prompt and Translation Behavior

The APK report shows explicit translation prompt templates. We should adopt that pattern rather than treating the model like a generic assistant.

The translation engine should take:

- source language
- target language
- input text

and construct a translation-focused prompt template. The prompt builder should live in one place so the app does not duplicate prompt logic across Flutter and native code.

A good first version is:

- Chinese-source template for Chinese source input
- English template for non-Chinese source input

Prompt-building logic should be testable independently.

## Runtime State Model

The app state model should explicitly represent both model and translation phases.

### Model Lifecycle States

- no model selected
- model selected
- loading model
- model ready
- unloading model
- model load failed

### Translation Lifecycle States

- idle
- ready
- translating
- completed
- cancelled
- failed

These states should remain separate enough that the UI can say, for example:

- model ready, no active translation
- model ready, translating
- no model loaded, translation unavailable

## Cancellation and Streaming

The APK report confirms cancellation and staged generation are core runtime concerns. The first real implementation should preserve that behavior.

Requirements:

- a translation request must be cancellable
- a cancelled request must not later overwrite controller state
- token or chunk output should be stream-capable even if the first UI only uses coarse-grained updates

This means the service boundary should already support progressive output or events, even if the very first macOS implementation chooses to batch small chunks instead of token-by-token rendering.

## Security and Safety

The APK includes a local sensitive-content AC filter. That is useful input, but it should not be part of the first milestone.

First milestone safety scope:

- local-only inference
- bounded generation defaults
- cancellation support
- explicit error handling
- no background downloads yet

Sensitive-text filtering is explicitly out of scope for the first real implementation milestone.

## Platform Plan

### Phase 1: macOS

Deliver real translation on macOS first.

Why macOS first:

- current development machine is Apple Silicon
- model validation has already been performed locally
- packaging and debugging are simpler than doing Android JNI and app-private downloads immediately
- it de-risks the real `llama.cpp` integration before mobile packaging complexity is added

### Phase 2: Android

Android then becomes the first mobile target. It is the closest conceptual match to the analyzed APK:

- JNI bridge
- packaged native libs
- app-private model directory
- later support for text-share translation entry points

### Phase 3: iOS

iOS follows after macOS and Android patterns are proven. It should use Apple-appropriate framework packaging and avoid Android-style dynamic backend discovery.

## File and Module Direction

The existing Flutter structure should evolve like this:

```text
flutter_app/lib/
├─ app.dart
├─ design/
├─ features/translator/
│  ├─ translator_page.dart
│  ├─ translator_controller.dart
│  ├─ translator_state.dart
│  ├─ translator_service.dart
│  ├─ translator_channel.dart
│  ├─ prompt_builder.dart
│  ├─ model_selection_state.dart
│  └─ model_catalog.dart
```

Native direction:

```text
flutter_app/macos/
├─ Runner/
│  ├─ TranslatorChannelHandler.swift
│  └─ Native/
│     ├─ translator_bridge.mm
│     ├─ translator_engine.cpp
│     └─ translator_engine.hpp
```

Android and iOS should later mirror the same abstraction names where practical.

## Testing Strategy

### Dart Tests

Add or extend tests for:

- prompt construction
- model selection state
- controller state transitions for model load and translation
- cancellation race handling
- service error propagation

### Native Validation

For the macOS real inference milestone, validation should include:

- model file can be selected and loaded
- short translation completes successfully
- cancel stops an in-flight request
- repeated translate/clear/translate flows do not leak state
- unload and reload work predictably

### End-to-End App Validation

- `flutter test`
- `flutter analyze`
- bounded `flutter run -d macos`
- at least one real translation smoke test through the app surface

## Non-Goals

Not part of the first real implementation milestone:

- multi-model support
- generic assistant/chat mode
- text sharing popup integration
- in-app model download center
- sensitive-word filtering
- Android and iOS full native parity
- App Store / Play Store distribution packaging

## Recommended Next Implementation Slice

The next implementation plan should focus on one sub-project only:

**macOS real inference integration for the existing Flutter translator workspace**

That plan should cover:

- replacing the mock service with a real macOS-backed service
- selecting a local GGUF file from the app
- loading and unloading the model
- performing one real translation request
- reporting errors and cancellation correctly

This keeps the work focused and produces the first meaningful product milestone without mixing in Android download infrastructure or iOS packaging work.
