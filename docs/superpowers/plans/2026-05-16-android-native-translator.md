# Android Native Translator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Android onto the same product route as macOS: import/download model into app-private storage, show only model name, then load and translate through a native `translator_engine`.

**Architecture:** Keep Flutter UI and controller behavior unchanged. Add an Android `MethodChannel` implementation in Kotlin, then move the current macOS C++ engine into a shared native directory and link it from Android through JNI. Android first supports only `arm64-v8a`, app-private `files/models/`, and the validated `Hy-MT1.5-1.8B-STQ1_0.gguf`.

**Tech Stack:** Flutter 3.35.5, Dart 3.9.2, Kotlin, Android Gradle, CMake, JNI, C++17, `llama.cpp` PR #22836, Android `ACTION_OPEN_DOCUMENT`, `HttpURLConnection`.

---

## File Structure

- Modify: `flutter_app/lib/features/translator/macos_translator_service.dart`
  - Rename platform-neutral factory behavior so Android uses the same channel-backed service.
- Create: `flutter_app/lib/features/translator/channel_translator_service.dart`
  - Owns platform-channel-backed `TranslatorService` for macOS and Android.
- Modify: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/MainActivity.kt`
  - Registers Android `MethodChannel`.
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt`
  - Implements Android model import, download status, cancellation, model load, translate, unload.
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelFileStore.kt`
  - Owns `files/models/`, GGUF validation, copy and delete logic.
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelDownloader.kt`
  - Owns default ModelScope download, progress state and cancellation.
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorNativeBridge.kt`
  - Thin Kotlin wrapper around JNI methods.
- Create: `flutter_app/android/app/src/main/cpp/CMakeLists.txt`
  - Builds Android native library for `arm64-v8a`.
- Create: `flutter_app/android/app/src/main/cpp/translator_jni.cpp`
  - Exposes JNI calls to Kotlin and delegates to shared `translator_engine`.
- Create: `flutter_app/native/translator_engine.cpp`
  - Moved shared implementation from macOS.
- Create: `flutter_app/native/translator_engine.hpp`
  - Moved shared header from macOS.
- Modify: `flutter_app/macos/Runner/translator_engine.cpp`
  - Replace with include shim or remove from Xcode sources after wiring shared file.
- Modify: `flutter_app/macos/Runner/translator_engine.hpp`
  - Replace with include shim or remove from Xcode sources after wiring shared file.
- Modify: `flutter_app/android/app/build.gradle.kts`
  - Enable CMake, limit ABI to `arm64-v8a`.
- Modify: `flutter_app/android/app/src/main/AndroidManifest.xml`
  - Add internet permission for downloader.
- Create: `flutter_app/test/features/translator/channel_translator_service_test.dart`
  - Verifies Android/macOS factory selects channel-backed service where applicable.
- Modify: `docs/PRD.md`
  - Mark Android behavior as planned and link implementation status.
- Modify: `docs/flutter_mobile_architecture.md`
  - Update Android native route once CMake/JNI is present.

---

## Task 1: Use Channel Service On Android

**Files:**
- Create: `flutter_app/lib/features/translator/channel_translator_service.dart`
- Modify: `flutter_app/lib/features/translator/macos_translator_service.dart`
- Test: `flutter_app/test/features/translator/channel_translator_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `flutter_app/test/features/translator/channel_translator_service_test.dart`:

```dart
import 'package:ai_offline_translator/features/translator/channel_translator_service.dart';
import 'package:ai_offline_translator/features/translator/translator_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel service is selected for Android and macOS', () {
    expect(
      isChannelTranslatorPlatform(TargetPlatform.android, isWeb: false),
      isTrue,
    );
    expect(
      isChannelTranslatorPlatform(TargetPlatform.macOS, isWeb: false),
      isTrue,
    );
    expect(
      isChannelTranslatorPlatform(TargetPlatform.iOS, isWeb: false),
      isFalse,
    );
    expect(
      isChannelTranslatorPlatform(TargetPlatform.android, isWeb: true),
      isFalse,
    );
  });

  test('default service remains mock on non-channel platforms', () {
    final service = createTranslatorServiceForPlatform(
      TargetPlatform.iOS,
      isWeb: false,
    );

    expect(service, isA<MockTranslatorService>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd flutter_app && flutter test test/features/translator/channel_translator_service_test.dart
```

Expected: FAIL because `channel_translator_service.dart`, `isChannelTranslatorPlatform`, and `createTranslatorServiceForPlatform` do not exist.

- [ ] **Step 3: Write minimal implementation**

Create `flutter_app/lib/features/translator/channel_translator_service.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'translator_channel.dart';
import 'translator_service.dart';

class ChannelTranslatorService implements TranslatorService {
  ChannelTranslatorService({TranslatorChannel? channel})
    : _channel = channel ?? const TranslatorChannel();

  final TranslatorChannel _channel;
  String? _modelPath;

  @override
  Future<void> loadModel({
    required String path,
    required int nCtx,
    required int nThreads,
  }) {
    _modelPath = path;
    return _channel.loadModel(path: path, nCtx: nCtx, nThreads: nThreads);
  }

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return _channel.translate(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      modelPath: _modelPath ?? '',
    );
  }

  @override
  Future<void> cancel() => _channel.cancel();

  @override
  Future<void> unloadModel() {
    _modelPath = null;
    return _channel.unloadModel();
  }

  @override
  Future<String> getModelStatus() => _channel.getModelStatus();
}

bool isChannelTranslatorPlatform(
  TargetPlatform platform, {
  required bool isWeb,
}) {
  return !isWeb &&
      (platform == TargetPlatform.macOS || platform == TargetPlatform.android);
}

TranslatorService createTranslatorServiceForPlatform(
  TargetPlatform platform, {
  required bool isWeb,
}) {
  if (isChannelTranslatorPlatform(platform, isWeb: isWeb)) {
    return ChannelTranslatorService();
  }
  return const MockTranslatorService();
}

TranslatorService createDefaultTranslatorService() {
  return createTranslatorServiceForPlatform(defaultTargetPlatform, isWeb: kIsWeb);
}
```

Modify `flutter_app/lib/features/translator/macos_translator_service.dart` to a compatibility export:

```dart
export 'channel_translator_service.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd flutter_app && flutter test test/features/translator/channel_translator_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run full Flutter checks**

Run:

```bash
cd flutter_app && flutter analyze && flutter test
```

Expected: `No issues found` and `All tests passed`.

- [ ] **Step 6: Commit**

```bash
git add flutter_app/lib/features/translator/channel_translator_service.dart \
  flutter_app/lib/features/translator/macos_translator_service.dart \
  flutter_app/test/features/translator/channel_translator_service_test.dart
git commit -m "Add Android channel translator service"
```

---

## Task 2: Add Android MethodChannel Skeleton

**Files:**
- Modify: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/MainActivity.kt`
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt`

- [ ] **Step 1: Implement channel registration**

Modify `MainActivity.kt`:

```kotlin
package com.kelegele.ai_offline_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TranslatorChannelHandler(this, flutterEngine.dartExecutor.binaryMessenger).register()
    }
}
```

Create `TranslatorChannelHandler.kt`:

```kotlin
package com.kelegele.ai_offline_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TranslatorChannelHandler(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "ai_offline_translator/translator")

    fun register() {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDefaultModelInfo" -> result.success(defaultModelInfo())
            "getModelDownloadStatus" -> result.success(idleDownloadStatus())
            "getModelStatus" -> result.success("Android 原生桥接已连接，模型未加载")
            "cancel" -> result.success(null)
            "unloadModel" -> result.success(null)
            "pickModelFile",
            "importModelFile",
            "downloadDefaultModel",
            "cancelModelDownload",
            "loadModel",
            "translate" -> result.error(
                "not_implemented",
                "Android 原生能力尚未接入：${call.method}",
                null,
            )
            else -> result.notImplemented()
        }
    }

    private fun defaultModelInfo(): Map<String, Any> = mapOf(
        "id" to "hymt15_18b_stq10",
        "displayName" to "Hy-MT1.5 1.8B STQ1_0",
        "filename" to "Hy-MT1.5-1.8B-STQ1_0.gguf",
        "downloadUrl" to "https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf",
    )

    private fun idleDownloadStatus(): Map<String, Any?> = mapOf(
        "state" to "idle",
        "receivedBytes" to 0L,
        "totalBytes" to 0L,
        "message" to "",
        "path" to null,
    )
}
```

- [ ] **Step 2: Build Android debug**

Run:

```bash
cd flutter_app && flutter build apk --debug
```

Expected: APK builds successfully. If Android SDK is missing, stop and record the exact missing SDK error in `docs/validation_status_2026-05-16.md`.

- [ ] **Step 3: Commit**

```bash
git add flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/MainActivity.kt \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt
git commit -m "Add Android translator channel skeleton"
```

---

## Task 3: Implement Android Model Store And Import

**Files:**
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelFileStore.kt`
- Modify: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt`

- [ ] **Step 1: Add model file store**

Create `ModelFileStore.kt`:

```kotlin
package com.kelegele.ai_offline_translator

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File

class ModelFileStore(private val context: Context) {
    val modelsDir: File
        get() = File(context.filesDir, "models").also { it.mkdirs() }

    fun copyFromUri(uri: Uri): File {
        val filename = displayNameFor(uri)
        require(filename.lowercase().endsWith(".gguf")) { "请选择 GGUF 模型文件。" }
        val destination = File(modelsDir, filename)
        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "无法读取选择的模型文件。" }
            destination.outputStream().use { output -> input.copyTo(output) }
        }
        require(isValidGguf(destination, minimumBytes = 0L)) { "文件不是有效的 GGUF 模型。" }
        return destination
    }

    fun defaultModelFile(): File = File(modelsDir, DEFAULT_MODEL_FILENAME)

    fun isValidGguf(file: File, minimumBytes: Long): Boolean {
        if (!file.exists() || file.length() < minimumBytes) return false
        file.inputStream().use { input ->
            val magic = ByteArray(4)
            if (input.read(magic) != 4) return false
            return magic.contentEquals(byteArrayOf(0x47, 0x47, 0x55, 0x46))
        }
    }

    private fun displayNameFor(uri: Uri): String {
        if (uri.scheme == ContentResolver.SCHEME_FILE) {
            return File(requireNotNull(uri.path)).name
        }
        context.contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) return cursor.getString(index)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: DEFAULT_MODEL_FILENAME
    }

    companion object {
        const val DEFAULT_MODEL_FILENAME = "Hy-MT1.5-1.8B-STQ1_0.gguf"
        const val MINIMUM_MODEL_BYTES = 100L * 1024L * 1024L
    }
}
```

- [ ] **Step 2: Implement Android file picker**

Modify `TranslatorChannelHandler.kt`:

```kotlin
private val modelFileStore = ModelFileStore(activity)
private var pendingImportResult: MethodChannel.Result? = null
private val importLauncher = activity.registerForActivityResult(
    androidx.activity.result.contract.ActivityResultContracts.OpenDocument()
) { uri ->
    val result = pendingImportResult ?: return@registerForActivityResult
    pendingImportResult = null
    if (uri == null) {
        result.success(null)
        return@registerForActivityResult
    }
    try {
        activity.contentResolver.takePersistableUriPermission(
            uri,
            android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
    } catch (_: SecurityException) {
    }
    try {
        result.success(modelFileStore.copyFromUri(uri).absolutePath)
    } catch (error: Throwable) {
        result.error("import_failed", error.message ?: "模型导入失败", null)
    }
}
```

Replace the `importModelFile` branch:

```kotlin
"importModelFile", "pickModelFile" -> {
    if (pendingImportResult != null) {
        result.error("import_in_progress", "模型导入正在进行。", null)
        return
    }
    pendingImportResult = result
    importLauncher.launch(arrayOf("*/*"))
}
```

- [ ] **Step 3: Add AndroidX activity dependency if compile requires it**

If `ActivityResultContracts` is unavailable, modify `flutter_app/android/app/build.gradle.kts`:

```kotlin
dependencies {
    implementation("androidx.activity:activity-ktx:1.9.3")
}
```

- [ ] **Step 4: Build Android debug**

Run:

```bash
cd flutter_app && flutter build apk --debug
```

Expected: build succeeds.

- [ ] **Step 5: Manual import check on device or emulator**

Run:

```bash
cd flutter_app && flutter run -d <android-device-id>
```

Expected:
- Tapping `导入模型` opens Android document picker.
- Selecting a small fake non-GGUF file shows `文件不是有效的 GGUF 模型。`.
- Selecting the real `Hy-MT1.5-1.8B-STQ1_0.gguf` copies it into app-private `files/models/`.
- UI displays only `Hy-MT1.5-1.8B-STQ1_0.gguf`, not a full path.

- [ ] **Step 6: Commit**

```bash
git add flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelFileStore.kt \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt \
  flutter_app/android/app/build.gradle.kts
git commit -m "Add Android model import flow"
```

---

## Task 4: Implement Android ModelScope Downloader

**Files:**
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelDownloader.kt`
- Modify: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt`
- Modify: `flutter_app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add internet permission**

Modify `AndroidManifest.xml` above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 2: Add downloader**

Create `ModelDownloader.kt`:

```kotlin
package com.kelegele.ai_offline_translator

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean

class ModelDownloader(private val modelFileStore: ModelFileStore) {
    private val executor = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private var task: Future<*>? = null

    @Volatile
    var status: Map<String, Any?> = idleStatus()
        private set

    fun downloadDefaultModel(onComplete: (Result<File>) -> Unit) {
        val destination = modelFileStore.defaultModelFile()
        if (modelFileStore.isValidGguf(destination, ModelFileStore.MINIMUM_MODEL_BYTES)) {
            status = completedStatus(destination, "模型已存在")
            onComplete(Result.success(destination))
            return
        }
        if (task != null) {
            onComplete(Result.failure(IllegalStateException("模型正在下载。")))
            return
        }
        cancelled.set(false)
        status = downloadingStatus(0L, 0L, "正在连接 ModelScope")
        val tempFile = File(destination.parentFile, "${destination.name}.download")
        task = executor.submit {
            try {
                val connection = URL(DEFAULT_MODEL_URL).openConnection() as HttpURLConnection
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                connection.instanceFollowRedirects = true
                val total = connection.contentLengthLong.takeIf { it > 0L } ?: 0L
                connection.inputStream.use { input ->
                    tempFile.outputStream().use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var received = 0L
                        while (true) {
                            if (cancelled.get()) throw InterruptedException("下载已取消。")
                            val count = input.read(buffer)
                            if (count < 0) break
                            output.write(buffer, 0, count)
                            received += count
                            status = downloadingStatus(received, total, "正在下载模型")
                        }
                    }
                }
                if (!modelFileStore.isValidGguf(tempFile, ModelFileStore.MINIMUM_MODEL_BYTES)) {
                    tempFile.delete()
                    throw IllegalStateException("下载的文件不是有效的 GGUF 模型。")
                }
                if (destination.exists()) destination.delete()
                tempFile.renameTo(destination)
                status = completedStatus(destination, "模型已下载")
                onComplete(Result.success(destination))
            } catch (error: Throwable) {
                tempFile.delete()
                status = if (cancelled.get()) {
                    cancelledStatus()
                } else {
                    failedStatus(error.message ?: "模型下载失败，请检查网络后重试。")
                }
                onComplete(Result.failure(error))
            } finally {
                task = null
            }
        }
    }

    fun cancel() {
        cancelled.set(true)
        task?.cancel(true)
        status = cancelledStatus()
    }

    companion object {
        const val DEFAULT_MODEL_URL =
            "https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf"

        fun idleStatus(): Map<String, Any?> = mapOf(
            "state" to "idle",
            "receivedBytes" to 0L,
            "totalBytes" to 0L,
            "message" to "",
            "path" to null,
        )

        fun downloadingStatus(received: Long, total: Long, message: String): Map<String, Any?> = mapOf(
            "state" to "downloading",
            "receivedBytes" to received,
            "totalBytes" to total,
            "message" to message,
            "path" to null,
        )

        fun completedStatus(file: File, message: String): Map<String, Any?> = mapOf(
            "state" to "completed",
            "receivedBytes" to file.length(),
            "totalBytes" to file.length(),
            "message" to message,
            "path" to file.absolutePath,
        )

        fun cancelledStatus(): Map<String, Any?> = mapOf(
            "state" to "cancelled",
            "receivedBytes" to 0L,
            "totalBytes" to 0L,
            "message" to "下载已取消。",
            "path" to null,
        )

        fun failedStatus(message: String): Map<String, Any?> = mapOf(
            "state" to "failed",
            "receivedBytes" to 0L,
            "totalBytes" to 0L,
            "message" to message,
            "path" to null,
        )
    }
}
```

- [ ] **Step 3: Wire downloader into channel**

In `TranslatorChannelHandler.kt`, add:

```kotlin
private val downloader = ModelDownloader(modelFileStore)
```

Replace method branches:

```kotlin
"downloadDefaultModel" -> {
    downloader.downloadDefaultModel { downloadResult ->
        activity.runOnUiThread {
            downloadResult
                .onSuccess { file -> result.success(file.absolutePath) }
                .onFailure { error ->
                    if (downloader.status["state"] == "cancelled") {
                        result.success(null)
                    } else {
                        result.error("download_failed", error.message ?: "模型下载失败，请检查网络后重试。", null)
                    }
                }
        }
    }
}
"cancelModelDownload" -> {
    downloader.cancel()
    result.success(null)
}
"getModelDownloadStatus" -> result.success(downloader.status)
```

- [ ] **Step 4: Build Android debug**

Run:

```bash
cd flutter_app && flutter build apk --debug
```

Expected: build succeeds.

- [ ] **Step 5: Manual download check on device or emulator**

Run:

```bash
cd flutter_app && flutter run -d <android-device-id>
```

Expected:
- Tapping `下载模型` starts ModelScope download.
- Progress text changes from connecting to downloaded bytes.
- Tapping `取消下载` cancels and removes partial file.
- Retrying can complete the download.
- UI displays only model filename after success.

- [ ] **Step 6: Commit**

```bash
git add flutter_app/android/app/src/main/AndroidManifest.xml \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/ModelDownloader.kt \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt
git commit -m "Add Android ModelScope downloader"
```

---

## Task 5: Move Translator Engine To Shared Native Directory

**Files:**
- Create: `flutter_app/native/translator_engine.cpp`
- Create: `flutter_app/native/translator_engine.hpp`
- Modify: `flutter_app/macos/Runner/translator_engine.cpp`
- Modify: `flutter_app/macos/Runner/translator_engine.hpp`
- Modify: `flutter_app/macos/Runner/translator_bridge.mm`

- [ ] **Step 1: Move engine source**

Move current macOS engine files:

```bash
mkdir -p flutter_app/native
cp flutter_app/macos/Runner/translator_engine.cpp flutter_app/native/translator_engine.cpp
cp flutter_app/macos/Runner/translator_engine.hpp flutter_app/native/translator_engine.hpp
```

- [ ] **Step 2: Replace macOS files with shims**

Replace `flutter_app/macos/Runner/translator_engine.hpp`:

```cpp
#pragma once

#include "../../native/translator_engine.hpp"
```

Replace `flutter_app/macos/Runner/translator_engine.cpp`:

```cpp
#include "../../native/translator_engine.cpp"
```

- [ ] **Step 3: Verify macOS still builds**

Run:

```bash
cd flutter_app && flutter build macos
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add flutter_app/native/translator_engine.cpp \
  flutter_app/native/translator_engine.hpp \
  flutter_app/macos/Runner/translator_engine.cpp \
  flutter_app/macos/Runner/translator_engine.hpp
git commit -m "Move translator engine to shared native directory"
```

---

## Task 6: Add Android JNI And CMake For arm64-v8a

**Files:**
- Create: `flutter_app/android/app/src/main/cpp/CMakeLists.txt`
- Create: `flutter_app/android/app/src/main/cpp/translator_jni.cpp`
- Create: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorNativeBridge.kt`
- Modify: `flutter_app/android/app/build.gradle.kts`
- Modify: `flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt`

- [ ] **Step 1: Add Kotlin native bridge**

Create `TranslatorNativeBridge.kt`:

```kotlin
package com.kelegele.ai_offline_translator

class TranslatorNativeBridge {
    init {
        System.loadLibrary("translator_engine_jni")
    }

    external fun loadModel(path: String, nCtx: Int, nThreads: Int): Boolean
    external fun translate(text: String, sourceLanguage: String, targetLanguage: String): String
    external fun cancel()
    external fun unloadModel()
    external fun getModelStatus(): String
    external fun getLastError(): String
}
```

- [ ] **Step 2: Add JNI skeleton**

Create `translator_jni.cpp`:

```cpp
#include <jni.h>
#include <memory>
#include <mutex>
#include <string>

#include "../../../../native/translator_engine.hpp"

namespace {
std::mutex g_mutex;
std::unique_ptr<TranslatorEngine> g_engine;
std::string g_last_error;

std::string to_string(JNIEnv *env, jstring value) {
  if (value == nullptr) return "";
  const char *chars = env->GetStringUTFChars(value, nullptr);
  std::string result(chars == nullptr ? "" : chars);
  if (chars != nullptr) env->ReleaseStringUTFChars(value, chars);
  return result;
}

jstring to_jstring(JNIEnv *env, const std::string &value) {
  return env->NewStringUTF(value.c_str());
}
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_loadModel(
    JNIEnv *env, jobject, jstring path, jint n_ctx, jint n_threads) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_engine = std::make_unique<TranslatorEngine>();
  if (!g_engine->load(to_string(env, path), n_ctx, n_threads)) {
    g_last_error = g_engine->last_error();
    g_engine.reset();
    return JNI_FALSE;
  }
  g_last_error.clear();
  return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_translate(
    JNIEnv *env, jobject, jstring text, jstring source_language, jstring target_language) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine || !g_engine->is_loaded()) {
    g_last_error = "模型未加载";
    return to_jstring(env, "");
  }
  auto output = g_engine->translate(
      to_string(env, text),
      to_string(env, source_language),
      to_string(env, target_language));
  if (!output.ok) {
    g_last_error = output.error;
    return to_jstring(env, "");
  }
  g_last_error.clear();
  return to_jstring(env, output.text);
}

extern "C" JNIEXPORT void JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_cancel(JNIEnv *, jobject) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) g_engine->cancel();
}

extern "C" JNIEXPORT void JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_unloadModel(JNIEnv *, jobject) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_engine) g_engine->unload();
  g_engine.reset();
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_getModelStatus(JNIEnv *env, jobject) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_engine || !g_engine->is_loaded()) return to_jstring(env, "未加载模型");
  return to_jstring(env, g_engine->status_text());
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_kelegele_ai_1offline_1translator_TranslatorNativeBridge_getLastError(JNIEnv *env, jobject) {
  std::lock_guard<std::mutex> lock(g_mutex);
  return to_jstring(env, g_last_error);
}
```

- [ ] **Step 3: Add CMake**

Create `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22.1)

project(translator_engine_jni)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(LLAMA_ROOT ${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/llama.cpp)
set(TRANSLATOR_NATIVE_ROOT ${CMAKE_CURRENT_LIST_DIR}/../../../../native)

add_library(translator_engine_jni SHARED
    translator_jni.cpp
    ${TRANSLATOR_NATIVE_ROOT}/translator_engine.cpp
)

target_include_directories(translator_engine_jni PRIVATE
    ${TRANSLATOR_NATIVE_ROOT}
    ${LLAMA_ROOT}/include
    ${LLAMA_ROOT}/common
    ${LLAMA_ROOT}/ggml/include
    ${LLAMA_ROOT}/ggml/src
)

find_library(log-lib log)

target_link_libraries(translator_engine_jni
    ${log-lib}
)
```

- [ ] **Step 4: Enable CMake and arm64-only ABI**

Modify `flutter_app/android/app/build.gradle.kts` inside `android { defaultConfig { ... } }`:

```kotlin
ndk {
    abiFilters += listOf("arm64-v8a")
}
externalNativeBuild {
    cmake {
        cppFlags += listOf("-std=c++17")
    }
}
```

Add inside `android { ... }`:

```kotlin
externalNativeBuild {
    cmake {
        path = file("src/main/cpp/CMakeLists.txt")
        version = "3.22.1"
    }
}
```

- [ ] **Step 5: Wire native load/translate branches**

In `TranslatorChannelHandler.kt`, add:

```kotlin
private val nativeBridge = TranslatorNativeBridge()
```

Replace branches:

```kotlin
"loadModel" -> {
    val path = call.argument<String>("path")
    val nCtx = call.argument<Int>("nCtx") ?: 256
    val nThreads = call.argument<Int>("nThreads") ?: 2
    if (path.isNullOrBlank()) {
        result.error("bad_args", "缺少模型加载参数", null)
        return
    }
    if (!nativeBridge.loadModel(path, nCtx, nThreads)) {
        result.error("load_failed", nativeBridge.getLastError().ifBlank { "模型加载失败" }, null)
        return
    }
    result.success(null)
}
"translate" -> {
    val text = call.argument<String>("text")
    val sourceLanguage = call.argument<String>("sourceLanguage") ?: "英语"
    val targetLanguage = call.argument<String>("targetLanguage") ?: "中文"
    if (text.isNullOrBlank()) {
        result.error("bad_args", "缺少翻译参数", null)
        return
    }
    Thread {
        val translated = nativeBridge.translate(text, sourceLanguage, targetLanguage)
        activity.runOnUiThread {
            val error = nativeBridge.getLastError()
            if (error.isNotBlank()) {
                result.error("translate_failed", error, null)
            } else {
                result.success(translated)
            }
        }
    }.start()
}
"cancel" -> {
    nativeBridge.cancel()
    result.success(null)
}
"unloadModel" -> {
    nativeBridge.unloadModel()
    result.success(null)
}
"getModelStatus" -> result.success(nativeBridge.getModelStatus())
```

- [ ] **Step 6: Build Android debug**

Run:

```bash
cd flutter_app && flutter build apk --debug --target-platform android-arm64
```

Expected: first run may fail because `llama.cpp` static libs are not linked. If so, do not hack around it; proceed to Task 7 to build/link Android `llama.cpp`.

- [ ] **Step 7: Commit if CMake config compiles to the expected link failure or succeeds**

```bash
git add flutter_app/android/app/build.gradle.kts \
  flutter_app/android/app/src/main/cpp/CMakeLists.txt \
  flutter_app/android/app/src/main/cpp/translator_jni.cpp \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorNativeBridge.kt \
  flutter_app/android/app/src/main/kotlin/com/kelegele/ai_offline_translator/TranslatorChannelHandler.kt
git commit -m "Add Android translator JNI bridge"
```

---

## Task 7: Build And Link llama.cpp For Android arm64-v8a

**Files:**
- Modify: `flutter_app/android/app/src/main/cpp/CMakeLists.txt`
- Create: `scripts/build_android_llama.sh`
- Modify: `docs/flutter_mobile_architecture.md`

- [ ] **Step 1: Add repeatable build script**

Create `scripts/build_android_llama.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="$ROOT/third_party/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build-android-arm64"

: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must point to the Android NDK}"

cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF

cmake --build "$BUILD_DIR" --target llama common ggml -j"$(sysctl -n hw.ncpu)"
```

Run:

```bash
chmod +x scripts/build_android_llama.sh
```

- [ ] **Step 2: Link static libraries in Android CMake**

Modify `CMakeLists.txt` with imported libraries:

```cmake
set(LLAMA_ANDROID_BUILD ${LLAMA_ROOT}/build-android-arm64)

add_library(llama STATIC IMPORTED)
set_target_properties(llama PROPERTIES IMPORTED_LOCATION
    ${LLAMA_ANDROID_BUILD}/src/libllama.a)

add_library(llama_common STATIC IMPORTED)
set_target_properties(llama_common PROPERTIES IMPORTED_LOCATION
    ${LLAMA_ANDROID_BUILD}/common/libcommon.a)

add_library(ggml STATIC IMPORTED)
set_target_properties(ggml PROPERTIES IMPORTED_LOCATION
    ${LLAMA_ANDROID_BUILD}/ggml/src/libggml.a)

target_link_libraries(translator_engine_jni
    llama_common
    llama
    ggml
    ${log-lib}
)
```

- [ ] **Step 3: Build llama.cpp for Android**

Run:

```bash
ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)" ./scripts/build_android_llama.sh
```

Expected: static libraries exist under `third_party/llama.cpp/build-android-arm64/`.

- [ ] **Step 4: Build Android APK**

Run:

```bash
cd flutter_app && flutter build apk --debug --target-platform android-arm64
```

Expected: APK builds for `arm64-v8a`.

- [ ] **Step 5: Commit**

```bash
git add scripts/build_android_llama.sh \
  flutter_app/android/app/src/main/cpp/CMakeLists.txt \
  docs/flutter_mobile_architecture.md
git commit -m "Link Android llama native runtime"
```

---

## Task 8: Android Device Smoke Test

**Files:**
- Modify: `docs/validation_status_2026-05-16.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Install and launch on Android**

Run:

```bash
cd flutter_app && flutter run -d <android-device-id> --target-platform android-arm64
```

Expected: app launches on an arm64 Android device or emulator.

- [ ] **Step 2: Verify import path**

Manual steps:

1. Tap `导入模型`.
2. Select `Hy-MT1.5-1.8B-STQ1_0.gguf`.
3. Confirm UI displays `Hy-MT1.5-1.8B-STQ1_0.gguf`.
4. Confirm UI does not display `/data/user/`, `/storage/`, or any full path.
5. Tap `加载模型`.

Expected: model loads or fails with a native error that includes the underlying `llama.cpp` reason.

- [ ] **Step 3: Verify translation**

Manual steps:

1. Input `Hello`.
2. Tap `翻译`.
3. Wait for output.

Expected: output is Chinese text equivalent to `你好` and does not contain prompt echo or repeated乱码.

- [ ] **Step 4: Verify downloader**

Manual steps:

1. Clear app data.
2. Launch app.
3. Tap `下载模型`.
4. Confirm progress appears.
5. Tap `取消下载`.
6. Confirm cancelled status and partial file removal.
7. Tap `下载模型` again and let it complete.

Expected: model downloads to `files/models/`, validates, and appears by filename only.

- [ ] **Step 5: Update validation docs**

Add to `docs/validation_status_2026-05-16.md`:

```markdown
## Android arm64-v8a 验证

- `flutter build apk --debug --target-platform android-arm64`：通过 / 未通过
- 模型导入到 `files/models/`：通过 / 未通过
- ModelScope 下载、取消、重试：通过 / 未通过
- `Hy-MT1.5-1.8B-STQ1_0.gguf` 加载：通过 / 未通过
- `Hello` 翻译为中文：通过 / 未通过

备注：
- 设备：
- Android 版本：
- 失败日志：
```

- [ ] **Step 6: Update CHANGELOG**

Add under `Unreleased`:

```markdown
### Added

- 新增 Android `arm64-v8a` 原生翻译链路，支持模型导入、ModelScope 下载、加载、翻译、取消和卸载。
```

- [ ] **Step 7: Final verification**

Run:

```bash
cd flutter_app && flutter analyze && flutter test && flutter build apk --debug --target-platform android-arm64
```

Expected: analyze clean, tests pass, APK builds.

- [ ] **Step 8: Commit**

```bash
git add docs/validation_status_2026-05-16.md CHANGELOG.md
git commit -m "Document Android native validation"
```

---

## Risk Controls

- Do not add x86 or x86_64 Android ABI in this phase.
- Do not expose a manual path input on Android.
- Do not show absolute paths in the Flutter UI.
- Do not commit downloaded GGUF files or native build artifacts.
- Do not switch back to CLI execution for Android.
- Keep download operations cancellable and off the UI thread.
- Keep inference operations cancellable and off the UI thread.
- If Android `llama.cpp` static linking becomes too large or unstable, stop and document the linker error before changing architecture.

## Self-Review

- PRD import/download/no-manual-path requirements are covered by Tasks 3 and 4.
- Android app-private `files/models/` requirement is covered by Task 3.
- Android `arm64-v8a` only requirement is covered by Task 6.
- Shared native `translator_engine` requirement is covered by Tasks 5, 6, and 7.
- Official `llama.cpp/common` route remains preserved because Task 5 moves the already validated macOS engine instead of rewriting prompt logic.
- Manual device verification is covered by Task 8.

