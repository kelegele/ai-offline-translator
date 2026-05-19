# REASONIX.md — ai-offline-translator

## Stack

- **Language / Framework** — Dart + Flutter (v3.9.2 SDK), targeting macOS & Android
- **Inference Engine** — llama.cpp (C++ static lib, PR #22836 for STQ1_0 format)
- **Native Bridge** — `translator_engine.hpp` (shared C++ header) + ObjC++ (macOS) / JNI (Android)
- **Key deps** — `file_picker` (model file import), `url_launcher` (model download), `flutter_lints` (lint rules), `cupertino_icons`

## Layout

| Path | What |
| --- | --- |
| `flutter_app/` | Flutter project root — UI (Dart), tests, platform runners, native bridge |
| `flutter_app/lib/` | Dart source — `features/translator/` (main pages/controller/channel), `design/` (theme/colors/spacing), `about/` |
| `flutter_app/native/translator_engine/` | Shared C++ inference engine — `translator_engine.hpp` + `.cpp` |
| `flutter_app/test/` | Flutter tests — widget test + per-feature unit tests under `features/` |
| `third_party/llama.cpp/` | Git submodule pinned to PR #22836 commit |
| `scripts/` | Build & smoke-test scripts — `setup.sh` / `setup.ps1`, `build_android_llama.sh`, `safe_llama_smoketest.py` / `.ps1` |
| `models/` | Model reference docs + `.gitignore`-d binary dirs (GGUF files excluded from Git) |
| `docs/` | GitHub Pages landing page (`index.html`), internal design docs (`internal/`), plans (`superpowers/`) |
| `DESIGN.md` | Visual design system (MiniMax-style colors, typography, spacing, buttons, cards) |
| `AGENTS.md` | Auto-pinned project rules — loaded into Reasonix system prompt every session |

## Commands

Run from `flutter_app/` (unless noted):

| Action | Command |
| --- | --- |
| Get deps | `flutter pub get` |
| Static analysis | `flutter analyze` |
| Run tests | `flutter test` |
| Run app | `flutter run -d <device>` (macOS / Android) |
| Build APK | `flutter build apk --target-platform android-arm64 --release` |
| Build macOS DMG | `flutter build macos --release` |
| Python scripts | `uv run scripts/safe_llama_smoketest.py` (never bare `python3`) |
| llama.cpp submodule | `git submodule update --init third_party/llama.cpp` |

## Conventions

- **File naming** — `snake_case.dart` for Dart files (main source + test files).
- **Class naming** — PascalCase. Methods, fields, channel names: lowerCamelCase.
- **Test files** — `_test.dart` suffix, colocated under `test/features/` mirroring `lib/features/`.
- **Imports** — `package:ai_offline_translator/` for project-internal imports (see `widget_test.dart`).
- **UI must follow `DESIGN.md`** — colors, radii, spacing, button/input/card styles defined there.
- **Commit style** — short imperative present tense, single focus per commit (visible in `git log`).
- **Only `arm64-v8a`** Android ABI — no x86/x86_64 Android targets.

## Watch out for

- `third_party/llama.cpp` is a **Git submodule** — update via `git submodule update --init`, never a clone. Pinned to PR #22836 for STQ1_0 support; updating must verify model loadability.
- **Never run interactive `llama-cli`** on Windows — use `uv run scripts/safe_llama_smoketest.py`.
- All Python **must** use `uv run` — direct `python3` is forbidden.
- `AGENTS.md` is loaded as system prompt every session — it contains binding rules (model safety, release discipline, learnt lessons like `v0.0.3` tag rollback).
- The `translator_engine.hpp` C++ API is shared across macOS & Android unchanged — platform differences live in the bridge layer (`translator_bridge.mm` / `translator_jni.cpp`).
- Model files (**`.gguf`**, **`.bin`**, **`.safetensors`**) are `.gitignore`-d — download or copy into `models/` manually.
