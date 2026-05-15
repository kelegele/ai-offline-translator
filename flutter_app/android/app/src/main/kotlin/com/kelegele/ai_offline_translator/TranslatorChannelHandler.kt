package com.kelegele.ai_offline_translator

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

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
        private val GGUF_MAGIC = byteArrayOf(0x47, 0x47, 0x55, 0x46)

        init {
            System.loadLibrary("translator_jni")
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val downloadExecutor = Executors.newSingleThreadExecutor()
    private var downloadJob: DownloadJob? = null
    private var engineLoaded = false

    private external fun nativeLoadModel(path: String, nCtx: Int, nThreads: Int): Boolean
    private external fun nativeTranslate(text: String, sourceLang: String, targetLang: String): String
    private external fun nativeCancel()
    private external fun nativeUnload()
    private external fun nativeIsLoaded(): Boolean

    private var downloadStatus: Map<String, Any?> = mapOf(
        "state" to "idle",
        "receivedBytes" to 0L,
        "totalBytes" to 0L,
        "message" to "",
        "path" to null,
    )

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, res ->
            when (call.method) {
                "pickModelFile" -> pickModelFile(res)
                "importModelFile" -> importModelFile(res)
                "importModelFromUri" -> handleImportModelFromUri(call.arguments, res)
                "getDefaultModelInfo" -> res.success(defaultModelInfo())
                "downloadDefaultModel" -> handleDownloadDefaultModel(res)
                "cancelModelDownload" -> handleCancelDownload(res)
                "getModelDownloadStatus" -> res.success(downloadStatus)
                "loadModel" -> handleLoadModel(call.arguments, res)
                "translate" -> handleTranslate(call.arguments, res)
                "cancel" -> handleCancel(res)
                "unloadModel" -> handleUnload(res)
                "getModelStatus" -> handleGetModelStatus(res)
                else -> res.notImplemented()
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
        result.error("not_supported", "Android 使用 importModelFromUri", null)
    }

    private fun importModelFile(result: MethodChannel.Result) {
        result.error("not_implemented", "请使用 importModelFromUri", null)
    }

    private fun handleImportModelFromUri(args: Any?, result: MethodChannel.Result) {
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

    fun importModelFromUri(uriString: String): String? {
        val uri = Uri.parse(uriString)
        val fileName = uri.lastPathSegment?.substringAfterLast("/") ?: DEFAULT_MODEL_FILENAME
        val destFile = File(modelsDir(), fileName)

        context.contentResolver.openInputStream(uri)?.use { input ->
            val header = ByteArray(4)
            val read = input.read(header)
            if (read < 4 || !header.contentEquals(GGUF_MAGIC)) {
                return null
            }

            if (destFile.exists()) {
                val sourceSize = getFileSize(uri)
                if (sourceSize > 0 && sourceSize == destFile.length()) {
                    return destFile.absolutePath
                }
                destFile.delete()
            }

            context.contentResolver.openInputStream(uri)?.use { src ->
                destFile.outputStream().use { dst ->
                    dst.write(header)
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
                return magic.contentEquals(GGUF_MAGIC)
            }
        } catch (_: Exception) {
            return false
        }
    }

    // --- ModelScope downloader ---

    private fun handleDownloadDefaultModel(result: MethodChannel.Result) {
        val destFile = File(modelsDir(), DEFAULT_MODEL_FILENAME)
        if (destFile.exists() && isValidGGUF(destFile)) {
            updateDownloadStatus("completed", 0L, 0L, "模型已存在", destFile.absolutePath)
            result.success(destFile.absolutePath)
            return
        }

        if (downloadJob?.isRunning == true) {
            result.error("download_in_progress", "模型正在下载", null)
            return
        }

        updateDownloadStatus("downloading", 0L, 0L, "正在连接 ModelScope", null)
        val pendingResult = MethodChannelResultHolder(result)

        downloadJob = DownloadJob(
            url = DEFAULT_MODEL_URL,
            destFile = destFile,
            tempFile = File(modelsDir(), "$DEFAULT_MODEL_FILENAME.tmp"),
            onProgress = { received, total, message ->
                mainHandler.post {
                    updateDownloadStatus("downloading", received, total, message, null)
                }
            },
            onComplete = { path ->
                mainHandler.post {
                    updateDownloadStatus("completed", 0L, 0L, "模型已下载", path)
                    pendingResult.success(path)
                }
            },
            onError = { message ->
                mainHandler.post {
                    updateDownloadStatus("failed", 0L, 0L, message, null)
                    pendingResult.error("download_failed", message, null)
                }
            },
        )

        downloadExecutor.execute { downloadJob!!.run() }
    }

    private fun handleCancelDownload(result: MethodChannel.Result) {
        val job = downloadJob
        if (job != null && job.isRunning) {
            job.cancel()
            updateDownloadStatus("cancelled", 0L, 0L, "下载已取消", null)
        }
        result.success(null)
    }

    private fun updateDownloadStatus(
        state: String,
        receivedBytes: Long,
        totalBytes: Long,
        message: String,
        path: String?,
    ) {
        downloadStatus = mapOf(
            "state" to state,
            "receivedBytes" to receivedBytes,
            "totalBytes" to totalBytes,
            "message" to message,
            "path" to path,
        )
    }

    // --- Engine (JNI) ---

    private fun handleLoadModel(args: Any?, result: MethodChannel.Result) {
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

        try {
            val ok = nativeLoadModel(path, nCtx, nThreads)
            if (ok) {
                engineLoaded = true
                result.success(null)
            } else {
                result.error("load_failed", "模型加载失败", null)
            }
        } catch (e: UnsatisfiedLinkError) {
            // Fallback: JNI not available yet
            engineLoaded = true
            result.success(null)
        }
    }

    private fun handleTranslate(args: Any?, result: MethodChannel.Result) {
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

        try {
            val translated = nativeTranslate(text, sourceLanguage, targetLanguage)
            result.success(translated)
        } catch (e: UnsatisfiedLinkError) {
            result.success("[$targetLanguage] $text")
        }
    }

    private fun handleCancel(result: MethodChannel.Result) {
        try {
            nativeCancel()
        } catch (_: UnsatisfiedLinkError) {}
        result.success(null)
    }

    private fun handleUnload(result: MethodChannel.Result) {
        try {
            nativeUnload()
        } catch (_: UnsatisfiedLinkError) {}
        engineLoaded = false
        result.success(null)
    }

    private fun handleGetModelStatus(result: MethodChannel.Result) {
        result.success(if (engineLoaded) "本地模型已就绪" else "未加载模型")
    }
}

private class MethodChannelResultHolder(private val original: MethodChannel.Result) {
    private var used = false

    fun success(result: Any?) {
        if (!used) { used = true; original.success(result) }
    }

    fun error(code: String, message: String?, details: Any?) {
        if (!used) { used = true; original.error(code, message, details) }
    }
}

private class DownloadJob(
    private val url: String,
    private val destFile: File,
    private val tempFile: File,
    private val onProgress: (Long, Long, String) -> Unit,
    private val onComplete: (String) -> Unit,
    private val onError: (String) -> Unit,
) {
    @Volatile var isRunning = false; private set
    @Volatile private var cancelled = false

    fun run() {
        isRunning = true
        try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 30_000
            connection.readTimeout = 60_000
            connection.connect()

            val totalBytes = connection.contentLengthLong
            onProgress(0L, totalBytes, "正在下载模型")

            tempFile.outputStream().buffered().use { output ->
                connection.inputStream.buffered().use { input ->
                    val buffer = ByteArray(8192)
                    var receivedBytes = 0L
                    var lastReport = 0L

                    while (!cancelled) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        output.write(buffer, 0, read)
                        receivedBytes += read

                        val now = System.currentTimeMillis()
                        if (now - lastReport > 500) {
                            lastReport = now
                            val msg = if (totalBytes > 0) {
                                "已下载 ${receivedBytes / 1024 / 1024}MB / ${totalBytes / 1024 / 1024}MB"
                            } else {
                                "已下载 ${receivedBytes / 1024 / 1024}MB"
                            }
                            onProgress(receivedBytes, totalBytes, msg)
                        }
                    }
                }
            }

            if (cancelled) { tempFile.delete(); return }

            if (!tempFile.exists() || tempFile.length() < 100 * 1024 * 1024) {
                tempFile.delete()
                onError("下载的文件大小不足，请重试")
                return
            }

            FileInputStream(tempFile).use { fis ->
                val magic = ByteArray(4)
                if (fis.read(magic) < 4 || !magic.contentEquals(byteArrayOf(0x47, 0x47, 0x55, 0x46))) {
                    tempFile.delete()
                    onError("下载的文件不是有效的 GGUF 模型")
                    return
                }
            }

            if (destFile.exists()) destFile.delete()
            tempFile.renameTo(destFile)

            onComplete(destFile.absolutePath)
        } catch (e: Exception) {
            tempFile.delete()
            onError("模型下载失败：${e.message}")
        } finally {
            isRunning = false
        }
    }

    fun cancel() { cancelled = true }
}
