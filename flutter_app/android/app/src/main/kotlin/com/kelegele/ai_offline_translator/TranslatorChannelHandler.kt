package com.kelegele.ai_offline_translator

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.ProtocolException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class TranslatorChannelHandler(
    private val context: Context,
) {
    companion object {
        private const val CHANNEL_NAME = "ai_offline_translator/translator"
        private const val MODELS_DIR = "models"
        private const val DEFAULT_MODEL_FILENAME = "Hy-MT2-1.8B-1.25Bit.gguf"
        private const val DEFAULT_MODEL_URL =
            "https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF/resolve/main/Hy-MT2-1.8B-1.25Bit.gguf"
        private const val MINIMUM_MODEL_BYTES: Long = 100 * 1024 * 1024
        private const val ENGINE_TAG = "AITranslatorEngine"
        private val GGUF_MAGIC = byteArrayOf(0x47, 0x47, 0x55, 0x46)

        init {
            System.loadLibrary("translator_jni")
        }
    }


    private val mainHandler = Handler(Looper.getMainLooper())
    private val downloadExecutor = Executors.newSingleThreadExecutor()
    private val engineExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_FOREGROUND)
            runnable.run()
        }.apply { name = "translator-engine" }
    }
    private var downloadJob: DownloadJob? = null
    @Volatile
    private var engineLoaded = false

    private external fun nativeLoadModel(path: String, nCtx: Int, nThreads: Int): Boolean
    private external fun nativeTranslate(text: String, sourceLang: String, targetLang: String): String
    private external fun nativeBeginTranslation(text: String, sourceLang: String, targetLang: String)
    private external fun nativeGenerateNextToken(): String?
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
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        methodChannel.setMethodCallHandler { call, res ->
            when (call.method) {
                "pickModelFile" -> pickModelFile(res)
                "importModelFile" -> importModelFile(res)
                "importModelFromUri" -> handleImportModelFromUri(call.arguments, res)
                "getDefaultModelInfo" -> res.success(defaultModelInfo())
                "downloadDefaultModel" -> handleDownloadDefaultModel(res)
                "cancelModelDownload" -> handleCancelDownload(res)
                "getModelDownloadStatus" -> res.success(downloadStatus)
                "findLocalModel" -> findLocalModel(res)
                "listLocalModels" -> listLocalModels(res)
                "loadModel" -> handleLoadModel(call.arguments, res)
                "translate" -> handleTranslate(call.arguments, res)
                "beginTranslation" -> handleBeginTranslation(call.arguments, res)
                "generateNextToken" -> handleGenerateNextToken(res)
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

    private fun findLocalModel(result: MethodChannel.Result) {
        try {
            val dir = modelsDir()
            val ggufFiles = dir.listFiles { f -> f.extension.lowercase() == "gguf" }
            if (ggufFiles != null && ggufFiles.isNotEmpty()) {
                val first = ggufFiles.first()
                result.success(mapOf("path" to first.absolutePath, "name" to first.name))
            } else {
                result.success(null)
            }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun listLocalModels(result: MethodChannel.Result) {
        try {
            val models = modelsDir()
                .listFiles { f -> f.isFile && f.extension.lowercase() == "gguf" }
                ?.sortedBy { it.name.lowercase() }
                ?.map { file ->
                    mapOf(
                        "path" to file.absolutePath,
                        "name" to file.name,
                        "sizeBytes" to file.length(),
                    )
                }
                ?: emptyList()
            result.success(models)
        } catch (_: Exception) {
            result.success(emptyList<Map<String, Any>>())
        }
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
            "id" to "hymt2_18b_125bit",
            "displayName" to "Hy-MT2 1.8B 1.25bit",
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

        val requestStartedAt = System.currentTimeMillis()
        engineExecutor.execute {
            val nativeStartedAt = System.currentTimeMillis()
            Log.i(
                ENGINE_TAG,
                "loadModel queued=${nativeStartedAt - requestStartedAt}ms",
            )
            try {
                val ok = nativeLoadModel(path, nCtx, nThreads)
                val nativeFinishedAt = System.currentTimeMillis()
                Log.i(
                    ENGINE_TAG,
                    "loadModel native=${nativeFinishedAt - nativeStartedAt}ms ok=$ok",
                )
                mainHandler.post {
                    if (ok) {
                        engineLoaded = true
                        result.success(null)
                    } else {
                        result.error("load_failed", "模型加载失败", null)
                    }
                }
            } catch (e: UnsatisfiedLinkError) {
                // Fallback: JNI not available yet
                mainHandler.post {
                    engineLoaded = true
                    result.success(null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("load_failed", e.message ?: "模型加载失败", null)
                }
            }
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

        val requestStartedAt = System.currentTimeMillis()
        engineExecutor.execute {
            val nativeStartedAt = System.currentTimeMillis()
            Log.i(
                ENGINE_TAG,
                "translate queued=${nativeStartedAt - requestStartedAt}ms chars=${text.length}",
            )
            try {
                val translated = nativeTranslate(text, sourceLanguage, targetLanguage)
                val nativeFinishedAt = System.currentTimeMillis()
                Log.i(
                    ENGINE_TAG,
                    "translate native=${nativeFinishedAt - nativeStartedAt}ms outputChars=${translated.length}",
                )
                mainHandler.post {
                    result.success(translated)
                }
            } catch (e: UnsatisfiedLinkError) {
                mainHandler.post {
                    result.success("[$targetLanguage] $text")
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("translate_failed", e.message ?: "翻译失败", null)
                }
            }
        }
    }

    private fun handleBeginTranslation(args: Any?, result: MethodChannel.Result) {
        Log.i(ENGINE_TAG, "beginTranslation called")
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

        engineExecutor.execute {
            try {
                Log.i(ENGINE_TAG, "beginTranslation text=$text chars=${text.length}")
                nativeBeginTranslation(text, sourceLanguage, targetLanguage)
                Log.i(ENGINE_TAG, "beginTranslation done")
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("translate_failed", e.message ?: "翻译启动失败", null)
                }
            }
        }
    }

    private fun handleGenerateNextToken(result: MethodChannel.Result) {
        var tokenCount = 0
        engineExecutor.execute {
            try {
                val piece = nativeGenerateNextToken()
                tokenCount++
                if (tokenCount <= 5) Log.i(ENGINE_TAG, "generateNextToken #$tokenCount piece=${piece?.take(20)}")
                mainHandler.post { result.success(piece) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("translate_failed", e.message ?: "token 生成失败", null)
                }
            }
        }
    }

    private fun handleCancel(result: MethodChannel.Result) {
        try {
            nativeCancel()
        } catch (_: UnsatisfiedLinkError) {}
        result.success(null)
    }

    private fun handleUnload(result: MethodChannel.Result) {
        engineExecutor.execute {
            try {
                nativeUnload()
            } catch (_: UnsatisfiedLinkError) {}
            mainHandler.post {
                engineLoaded = false
                result.success(null)
            }
        }
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
        var connection: HttpURLConnection? = null
        try {
            onProgress(0L, 0L, "正在解析下载地址")
            connection = openDownloadConnection(url)

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
            Log.e("AITranslatorDownload", "Model download failed", e)
            tempFile.delete()
            onError("模型下载失败：${e.message ?: e.javaClass.simpleName}")
        } finally {
            connection?.disconnect()
            isRunning = false
        }
    }

    fun cancel() { cancelled = true }

    private fun openDownloadConnection(rawUrl: String): HttpURLConnection {
        var currentUrl = rawUrl
        repeat(6) { redirectCount ->
            if (cancelled) throw InterruptedException("下载已取消")

            val connection = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = 15_000
                readTimeout = 30_000
                requestMethod = "GET"
                setRequestProperty("Accept", "application/octet-stream,*/*")
                setRequestProperty("Accept-Encoding", "identity")
                setRequestProperty("Connection", "close")
                setRequestProperty(
                    "User-Agent",
                    "AI-Offline-Translator/1.0 Android Model Downloader",
                )
            }

            val host = URL(currentUrl).host
            onProgress(0L, 0L, "正在连接 $host")
            val responseCode = connection.responseCode

            if (responseCode in 300..399) {
                val location = connection.getHeaderField("Location")
                connection.disconnect()
                if (location.isNullOrBlank()) {
                    throw ProtocolException("下载地址跳转缺少 Location")
                }
                currentUrl = URL(URL(currentUrl), location).toString()
                onProgress(0L, 0L, "正在跳转下载源 ${redirectCount + 1}")
                return@repeat
            }

            if (responseCode != HttpURLConnection.HTTP_OK &&
                responseCode != HttpURLConnection.HTTP_PARTIAL
            ) {
                val message = connection.responseMessage ?: "HTTP $responseCode"
                connection.disconnect()
                throw ProtocolException("下载源响应异常：$responseCode $message")
            }

            return connection
        }

        throw ProtocolException("下载地址跳转次数过多")
    }
}
