# Engine Upgrade + In-App Model Download Design

> **Status:** Approved · 2026-05-16
> **Follows:** `docs/superpowers/specs/2026-05-15-offline-translator-app-implementation-design.md`

**Goal:** Replace the CGI-based LLAMA invocation with a C++ translation engine linked against `llama.cpp` and add an in-app model download flow for a clean offline-model delivery UX.

**Architecture:** One C++ `translator_engine` linked directly to `libllama` (headers + objects from `third_party/llama.cpp`), exposed to Swift through a single ObjC++ header. The Dart side keeps `TranslatorService` as the stable contract. The engine is usable from both the Flutter macOS native host and a future Android/JNI path. In-app model download starts with a simple import page (URL + progress) that targets ModelScope; the downloaded file lands in the app’s private Application Support directory.

**Tech Stack:** Flutter 3.35.5, Dart 3.9.2, Swift, ObjC++, C++17, `libllama` from `third_party/llama.cpp`, ModelScope download API, `Foundation` networking.

---

## 1. Motivation & Current State

**Current:** The Flutter macOS host shells out to `llama-completion` as a subprocess. This works but gives us poor error handling, no streaming, no native state visibility, and ties our runtime to a CLI binary that may not exist on other platforms.

**Target:** Link `libllama` directly so we have:

- native error codes instead of stderr parsing
- in-process model lifecycle (load once, translate many)
- cancellation via a native flag rather than SIGTERM
- a natural path to Android/iOS JNI/ObjC bridges later

**Model delivery target:** Instead of asking the user to find and paste a GGUF path, the app should be able to download the model itself — with progress, retry, and final placement into the macOS app's Application Support folder.

---

## 2. Engine Architecture

### 2.1 C++ Core

`translator_engine` is a single header + implementation pair in `flutter_app/macos/Runner/Native/`:

```
translator_engine.hpp
translator_engine.cpp
```

**API:**

```cpp
struct TranslatorEngineConfig {
  std::string model_path;
  int         n_ctx     = 256;
  int         n_threads = 2;
  bool        gpu_offload = false;
};

struct TranslatorEngineResult {
  std::string text;
  bool        cancelled = false;
  std::string error;
};

class TranslatorEngine {
public:
  bool load(const TranslatorEngineConfig& config);
  void unload();
  bool is_loaded() const;

  TranslatorEngineResult translate(const std::string& prompt,
                                   const std::string& source_lang,
                                   const std::string& target_lang);
  void cancel();

  std::string status_text() const;
};
```

**Implementation notes:**

- `load()` calls `llama_model_load_from_file()` → `llama_new_context_with_model()`.
- `translate()` tokenises `prompt`, runs sampling loop with model-inherited sampling params, collects output until EOS/stop or cancel, then detokenises.
- `cancel()` sets an `std::atomic<bool>` flag checked in the sampling loop.
- All Metal/GPU config flows through the `gpu_offload` flag; CPU-only is the safe default.
- The engine never forks; it runs on the caller’s thread. The macOS Swift layer calls it from a background `DispatchQueue`.

### 2.2 Swift / ObjC++ Bridge

A single ObjC++ file (`translator_bridge.mm`) wraps `TranslatorEngine` in a thin ObjC class so Swift can use it without C++ headers:

```objc
@interface TranslatorBridge : NSObject
- (BOOL)loadWithPath:(NSString *)path nCtx:(NSInteger)nCtx nThreads:(NSInteger)nThreads error:(NSError **)error;
- (void)unload;
- (BOOL)isLoaded;

- (void)translateText:(NSString *)text
       sourceLanguage:(NSString *)source
       targetLanguage:(NSString *)target
           completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion;
- (void)cancel;
- (NSString *)statusText;
@end
```

### 2.3 Xcode Integration

- Add `translator_engine.hpp`, `translator_engine.cpp`, and `translator_bridge.mm` to the Runner target.
- Add `third_party/llama.cpp/include` and `third_party/llama.cpp/ggml/include` to header search paths.
- Link against `libllama.a` (built from `third_party/llama.cpp` with CMake or a standalone build script).
- Add standard C++17 dialect and `-fobjc-arc` for the `.mm` file.

---

## 3. Model Download / Import

### 3.1 First Milestone: Simple Import

Add a Flutter page that accepts a ModelScope URL, downloads the file, and stores it in the app's private directory.

**Dart side:**

- `ModelDownloadPage` — a Flutter page with:
  - URL text field (pre-filled with the recommended ModelScope GGUF URL)
  - download button
  - progress bar
  - status text
- `ModelDownloadService` — Dart class that:
  - resolves the app's Application Support directory via `path_provider`
  - streams download progress
  - validates that the downloaded file is a GGUF (> 1 KB, starts with `GGUF` magic)
  - stores the path in shared preferences
- The existing `TranslatorPage` reads the stored path on startup and auto-loads it.

**macOS path:** `~/Library/Application Support/com.kelegele.aiOfflineTranslator/models/`

### 3.2 Dependency

Add `path_provider` and `http` to `pubspec.yaml` for download + path resolution.

### 3.3 App Startup Flow

```
App launch → read stored model path from prefs
  → if path exists and file exists → auto-load model
  → if path missing or file gone → show "no model" state with a link to download page
```

---

## 4. File Structure (New & Modified)

```
flutter_app/
├─ lib/features/translator/
│  ├─ translator_engine_service.dart      (new – replaces CLI service)
│  ├─ model_download_page.dart            (new)
│  ├─ model_download_service.dart         (new)
│  ├─ model_repository.dart               (new – persist path)
│  └─ translator_page.dart               (modify – add download nav)
├─ macos/Runner/Native/
│  ├─ translator_engine.hpp               (new)
│  ├─ translator_engine.cpp               (new)
│  └─ translator_bridge.mm                (new)
├─ macos/Runner/
│  ├─ TranslatorChannelHandler.swift      (modify – use bridge)
│  └─ Runner.xcodeproj/project.pbxproj    (modify – add files + link lib)
├─ pubspec.yaml                           (modify – add path_provider, http)
└─ scripts/
   └─ build_libllama.sh                   (new – build libllama.a from submodule)
```

---

## 5. Engine Implementation — Key Details

### Tokenisation

Use the model's tokeniser via `llama_tokenize()`:

```cpp
std::vector<llama_token> tokens = llama_tokenize(model, prompt, true, true);
```

### Sampling & Generation

```cpp
for (int i = 0; i < n_predict; i++) {
  if (cancelled_.load()) break;
  llama_decode(ctx, batch);
  // ... sample next token ...
  if (token == llama_token_eos(model)) break;
  tokens.push_back(token);
}
std::string result = llama_detokenize(model, tokens);
```

### Prompt Building

Reuse `PromptBuilder` logic but in C++:

```cpp
std::string build_prompt(const std::string& text,
                         const std::string& source,
                         const std::string& target) {
  if (source == "中文") {
    return "请将以下内容翻译为" + target + "：\n\n" + text;
  }
  return "Please translate to " + target + ", without additional explanation:\n\n" + text;
}
```

### Safety Bounds (CPU-first)

- `n_ctx = 256`
- `n_predict = 128`
- `n_threads = 2`
- `n_batch = 256`
- 60s wall-clock timeout enforced in Swift layer
- CPU-only until Metal STQ1_0 path is confirmed working

---

## 6. Scope

### In this milestone

- C++ translator_engine linked to libllama
- ObjC++ bridge
- Xcode project integration
- Model download page (ModelScope URL → app private dir)
- Auto-load saved model on app start
- Remove old CLI-based `LlamaCliTranslatorService`

### Out of scope (next milestones)

- Android/iOS native bridges
- Model catalog / multiple models
- Streaming token-by-token to UI
- Sensitive word filtering
- Chat / history mode

---

## 7. Self-Review

- ✅ No placeholders or TBDs
- ✅ Architecture consistent with prior spec
- ✅ Scope matches "engine upgrade + model download"
- ✅ Engine API matches Swift/Dart bridge needs
- ✅ Model download path works on macOS with path_provider
