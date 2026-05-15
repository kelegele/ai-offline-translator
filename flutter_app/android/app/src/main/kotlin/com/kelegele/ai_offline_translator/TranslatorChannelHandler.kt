package com.kelegele.ai_offline_translator

import android.content.Context
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class TranslatorChannelHandler(
    private val context: Context,
) {
    companion object {
        private const val CHANNEL_NAME = "ai_offline_translator/translator"
        private const val MODELS_DIR = "models"
        private const val DEFAULT_MODEL_FILENAME = "Hy-MT1.5-1.8B-STQ1_0.gguf"
        private const val DEFAULT_MODEL_URL =
            "https://modelscope.cn/models/AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF/resolve/master/Hy-MT1.5-1.8B-STQ1_0.gguf"
        private const val MINIMUM_MODEL_BYTES: Long = 100 * 1024 * 1024
        private val GGUF_MAGIC = intArrayOf(0x47, 0x47, 0x55, 0x46)
    }

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickModelFile" -> pickModelFile(result)
                "importModelFile" -> importModelFile(result)
                "getDefaultModelInfo" -> result(defaultModelInfo())
                "downloadDefaultModel" -> result.notImplemented()
                "cancelModelDownload" -> result.notImplemented()
                "getModelDownloadStatus" -> result(emptyMap<String, Any>())
                "importModelFromUri" -> handleImportModelFromUri(call.arguments, result)
                "loadModel" -> handleLoadModel(call.arguments, result)
                "translate" -> handleTranslate(call.arguments, result)
                "cancel" -> handleCancel(result)
                "unloadModel" -> handleUnload(result)
                "getModelStatus" -> handleGetModelStatus(result)
                else -> result.notImplemented()
            }
        }
    }

    // --- Model directory ---

    private fun modelsDir(): File {
        val dir = File(context.filesDir, MODELS_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    // --- File picking / import ---

    private fun pickModelFile(result: MethodChannel.Result) {
        // Android does not support pickModelFile via MethodChannel directly.
        // The Flutter side should use file_picker or a platform-specific intent.
        result.error(
            "not_supported",
            "Android 使用 importModelFile 而非 pickModelFile",
            null,
        )
    }

    private fun importModelFile(result: MethodChannel.Result) {
        // On Android, the Flutter side uses file_picker to get a content URI,
        // then calls importModelFile with the URI string.
        // For now, this is a placeholder that will be enhanced with intent-based picking.
        result.error(
            "not_implemented",
            "请使用 Flutter 侧的文件选择器获取模型 URI，然后调用 importModelFromUri",
            null,
        )
    }

    /**
     * Import a model file from a content URI (obtained via file_picker or system picker).
     * Validates GGUF magic and copies to app-private models directory.
     */
    fun importModelFromUri(uriString: String): String? {
        val uri = Uri.parse(uriString)
        val fileName = uri.lastPathSegment?.substringAfterLast("/") ?: DEFAULT_MODEL_FILENAME
        val destFile = File(modelsDir(), fileName)

        // Check if already imported with same size
        context.contentResolver.openInputStream(uri)?.use { input ->
            val header = ByteArray(4)
            val read = input.read(header)
            if (read < 4 || !header.contentEquals(
                    GGUF_MAGIC.map { it.toByte() }.toByteArray()
                )
            ) {
                return null
            }

            if (destFile.exists()) {
                val sourceSize = getFileSize(uri)
                if (sourceSize > 0 && sourceSize == destFile.length()) {
                    return destFile.absolutePath
                }
                destFile.delete()
            }

            // Copy the full file
            context.contentResolver.openInputStream(uri)?.use { src ->
                destFile.outputStream().use { dst ->
                    // Write the magic bytes first (already read)
                    dst.write(header)
                    // Then copy the rest
                    src.copyTo(dst)
                }
            }
        }

        return if (destFile.exists()) destFile.absolutePath else null
    }

    private fun getFileSize(uri: Uri): Long {
        return try {
            context.contentResolver.openAssetFileDescriptor(uri, "r")?.use {
                it.length
            } ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    private fun handleImportModelFromUri(args: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val map = args as? Map<String, Any>
        val uriString = map?.get("uri") as? String
        if (uriString == null) {
            result.error("bad_args", "缺少模型 URI", null)
            return
        }
        val importedPath = importModelFromUri(uriString)
        if (importedPath != null) {
            result.success(importedPath)
        } else {
            result.error("import_failed", "导入失败：文件不是有效的 GGUF 模型", null)
        }
    }

    // --- Default model info ---

    private fun defaultModelInfo(): Map<String, Any> {
        return mapOf(
            "id" to "hymt15_18b_stq10",
            "displayName" to "Hy-MT1.5 1.8B STQ1_0",
            "filename" to DEFAULT_MODEL_FILENAME,
            "downloadUrl" to DEFAULT_MODEL_URL,
        )
    }

    // --- GGUF validation ---

    private fun isValidGGUF(file: File, minimumBytes: Long = MINIMUM_MODEL_BYTES): Boolean {
        if (!file.exists() || file.length() < minimumBytes) return false
        try {
            FileInputStream(file).use { fis ->
                val magic = ByteArray(4)
                val read = fis.read(magic)
                if (read < 4) return false
                return magic.contentEquals(
                    GGUF_MAGIC.map { it.toByte() }.toByteArray()
                )
            }
        } catch (_: Exception) {
            return false
        }
    }

    // --- Engine stubs (will be connected to JNI in Task 5) ---

    private var engineLoaded = false

    private fun handleLoadModel(args: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val map = args as? Map<String, Any> ?: run {
            result.error("bad_args", "缺少模型加载参数", null)
            return
        }
        val path = map["path"] as? String ?: run {
            result.error("bad_args", "缺少模型路径", null)
            return
        }
        val nCtx = (map["nCtx"] as? Number)?.toInt() ?: 256
        val nThreads = (map["nThreads"] as? Number)?.toInt() ?: 2

        val file = File(path)
        if (!file.exists()) {
            result.error("load_failed", "模型文件不存在：$path", null)
            return
        }
        if (!isValidGGUF(file)) {
            result.error("load_failed", "文件不是有效的 GGUF 模型", null)
            return
        }

        // TODO: Replace with JNI call to translator_engine in Task 5
        engineLoaded = true
        result.success(null)
    }

    private fun handleTranslate(args: Any?, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val map = args as? Map<String, Any> ?: run {
            result.error("bad_args", "缺少翻译参数", null)
            return
        }
        val text = map["text"] as? String ?: ""
        val sourceLanguage = map["sourceLanguage"] as? String ?: "英语"
        val targetLanguage = map["targetLanguage"] as? String ?: "中文"

        if (!engineLoaded) {
            result.error("translate_failed", "模型未加载", null)
            return
        }

        // TODO: Replace with JNI call to translator_engine in Task 5
        result.success("[$targetLanguage] $text")
    }

    private fun handleCancel(result: MethodChannel.Result) {
        // TODO: Cancel JNI inference in Task 5
        result.success(null)
    }

    private fun handleUnload(result: MethodChannel.Result) {
        engineLoaded = false
        // TODO: Unload JNI model in Task 5
        result.success(null)
    }

    private fun handleGetModelStatus(result: MethodChannel.Result) {
        result.success(if (engineLoaded) "本地模型已就绪" else "未加载模型")
    }
}
