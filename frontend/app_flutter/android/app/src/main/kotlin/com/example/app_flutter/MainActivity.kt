package com.example.app_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import android.util.Base64
import java.security.SecureRandom
import java.security.MessageDigest
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var oauthChannel: MethodChannel? = null
    private var initialOAuthLink: String? = null
    private fun isOAuthLink(uri: Uri?): Boolean = uri?.scheme == "com.creo.app" && uri.host == "app" && uri.path == "/auth/google/callback"
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isOAuthLink(intent.data)) {
            initialOAuthLink = intent.dataString
            oauthChannel?.invokeMethod("link", initialOAuthLink)
        }
    }
    private var pending: MethodChannel.Result? = null
    private val fileWorker = Executors.newSingleThreadExecutor()
    private val requestCode = 5831
    private val saveRequestCode = 5832
    private var mediaOnly = true
    private val selections = mutableMapOf<String, Uri>()
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (isOAuthLink(intent?.data)) initialOAuthLink = intent.dataString
        oauthChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "creo/oauth")
        oauthChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitialLink" -> { val link = initialOAuthLink; initialOAuthLink = null; result.success(link) }
                "createPkce" -> {
                    val random = ByteArray(32).also { SecureRandom().nextBytes(it) }
                    val flags = Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
                    val verifier = Base64.encodeToString(random, flags)
                    val challenge = Base64.encodeToString(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII)), flags)
                    result.success(mapOf("verifier" to verifier, "challenge" to challenge))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "creo/workstation_files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> {
                        if (pending != null || pendingSave != null) result.error("BUSY", "A file operation is already open.", null)
                        else {
                            pending = result
                            mediaOnly = call.argument<Boolean>("mediaOnly") != false
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                if (mediaOnly) putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/mp4", "video/quicktime"))
                            }
                            try { startActivityForResult(intent, requestCode) }
                            catch (_: Exception) { pending = null; result.error("PICKER_FAILED", "No document provider is available.", null) }
                        }
                    }
                    "save" -> {
                        if (pendingSave != null || pending != null) {
                            result.error("BUSY", "A file operation is already open.", null)
                        } else {
                            val bytes = call.argument<ByteArray>("bytes")
                            val name = call.argument<String>("name")
                                ?.substringAfterLast('/')
                                ?.substringAfterLast('\\')
                            val mime = call.argument<String>("mimeType")
                            if (bytes == null || bytes.isEmpty() || name.isNullOrBlank() || mime.isNullOrBlank()) {
                                result.error("INVALID_DOWNLOAD", "The downloaded file is incomplete.", null)
                            } else {
                                pendingSave = result
                                pendingSaveBytes = bytes
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = mime
                                    putExtra(Intent.EXTRA_TITLE, name)
                                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                                }
                                try { startActivityForResult(intent, saveRequestCode) }
                                catch (_: Exception) {
                                    pendingSave = null; pendingSaveBytes = null
                                    result.error("SAVE_PICKER_FAILED", "No file save location is available.", null)
                                }
                            }
                        }
                    }
                    "release" -> {
                        val path = call.argument<String>("path")
                        val folder = File(cacheDir, "workstation-files").canonicalFile
                        val file = path?.let { File(it).canonicalFile }
                        if (file != null && file.parentFile == folder) { selections.remove(file.path); file.delete() }
                        result.success(null)
                    }
                    "preview" -> {
                        val path = call.argument<String>("path")
                        val uri = selections[path]
                        if (uri == null) result.error("FILE_UNAVAILABLE", "Select this file again before previewing it.", null)
                        else try {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, contentResolver.getType(uri) ?: "*/*")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent); result.success(null)
                        } catch (_: Exception) { result.error("PREVIEW_UNAVAILABLE", "No application could preview this file.", null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(request: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(request, resultCode, data)
        if (request == saveRequestCode) {
            val reply = pendingSave ?: return
            val destination = data?.data
            val bytes = pendingSaveBytes
            if (resultCode != Activity.RESULT_OK || destination == null) {
                pendingSave = null; pendingSaveBytes = null
                reply.success(false)
                return
            }
            if (bytes == null) {
                pendingSave = null; pendingSaveBytes = null
                reply.error("SAVE_FAILED", "The downloaded file is no longer available.", null)
                return
            }
            fileWorker.execute {
                try {
                    contentResolver.openOutputStream(destination, "w")?.use { it.write(bytes) }
                        ?: throw IllegalStateException()
                    runOnUiThread {
                        if (pendingSave === reply && !isDestroyed) {
                            pendingSave = null; pendingSaveBytes = null
                            reply.success(true)
                        }
                    }
                } catch (_: Exception) {
                    runOnUiThread {
                        if (pendingSave === reply && !isDestroyed) {
                            pendingSave = null; pendingSaveBytes = null
                            reply.error("SAVE_FAILED", "The file could not be written to that location.", null)
                        }
                    }
                }
            }
            return
        }
        if (request != requestCode) return
        val reply = pending ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null; reply.success(null); return
        }
        fileWorker.execute {
            var copy: File? = null
            try {
                var name = "selected-file"
                var reportedSize = -1L
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (nameColumn >= 0) name = cursor.getString(nameColumn) ?: name
                        if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) reportedSize = cursor.getLong(sizeColumn)
                    }
                }
                val ext = name.substringAfterLast('.', "").lowercase()
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                    ?: contentResolver.getType(uri) ?: "application/octet-stream"
                val maxBytes = (if (!mediaOnly) 50L else if (mime.startsWith("video/")) 500L else 10L) * 1024 * 1024
                require(!mediaOnly || mime in listOf("video/mp4", "video/quicktime", "image/png", "image/jpeg", "image/webp", "image/gif"))
                require(reportedSize <= maxBytes)
                val folder = File(cacheDir, "workstation-files").apply { mkdirs() }
                val target = File.createTempFile("selection-", ".$ext", folder)
                copy = target
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= maxBytes)
                            output.write(buffer, 0, count)
                        }
                    }
                } ?: throw IllegalStateException()
                val payload = mapOf("path" to target.path, "name" to name, "size" to target.length(), "mimeType" to mime)
                runOnUiThread {
                    if (pending === reply && !isDestroyed) { pending = null; selections[target.path] = uri; reply.success(payload) }
                    else { target.delete() }
                }
            } catch (_: Exception) {
                copy?.delete()
                runOnUiThread {
                    if (pending === reply && !isDestroyed) {
                        pending = null; reply.error("FILE_READ_FAILED", "Choose a readable file within the supported size limit.", null)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        pending?.error("CANCELLED", "File selection was interrupted.", null)
        pending = null
        pendingSave?.error("CANCELLED", "File saving was interrupted.", null)
        pendingSave = null
        pendingSaveBytes = null
        fileWorker.shutdown()
        super.onDestroy()
    }
}
