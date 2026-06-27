package com.example.mobile_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val CHANNEL = "ai_locker/image_picker"
    private val REQUEST_CAMERA = 1001
    private val REQUEST_GALLERY = 1002
    private val REQUEST_CAMERA_PERMISSION = 2001
    private val REQUEST_STORAGE_PERMISSION = 2002

    private var pendingResult: MethodChannel.Result? = null
    private var cameraImagePath: String? = null
    private var pendingSource: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickImage") {
                    // Clear any previous pending result
                    pendingResult = result
                    val source = call.argument<String>("source") ?: "gallery"
                    pendingSource = source

                    if (source == "camera") {
                        checkCameraPermissionAndOpen()
                    } else {
                        checkStoragePermissionAndOpen()
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    // ── PERMISSIONS ────────────────────────────────────────────

    private fun checkCameraPermissionAndOpen() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED) {
            openCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA_PERMISSION
            )
        }
    }

    private fun checkStoragePermissionAndOpen() {
        // Android 13+ uses READ_MEDIA_IMAGES, older uses READ_EXTERNAL_STORAGE
        val permission = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

        if (ContextCompat.checkSelfPermission(this, permission)
            == PackageManager.PERMISSION_GRANTED) {
            openGallery()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(permission),
                REQUEST_STORAGE_PERMISSION
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            REQUEST_CAMERA_PERMISSION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openCamera()
                } else {
                    safeReply { it.error("PERMISSION_DENIED", "Camera permission denied", null) }
                }
            }
            REQUEST_STORAGE_PERMISSION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openGallery()
                } else {
                    safeReply { it.error("PERMISSION_DENIED", "Storage permission denied", null) }
                }
            }
        }
    }

    // ── INTENTS ────────────────────────────────────────────────

    private fun openCamera() {
        try {
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            val photoFile = createImageFile()
            cameraImagePath = photoFile.absolutePath
            val photoURI = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                photoFile
            )
            intent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)
            startActivityForResult(intent, REQUEST_CAMERA)
        } catch (e: Exception) {
            safeReply { it.error("CAMERA_ERROR", e.message, null) }
        }
    }

    private fun openGallery() {
        try {
            val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
            intent.type = "image/*"
            startActivityForResult(intent, REQUEST_GALLERY)
        } catch (e: Exception) {
            safeReply { it.error("GALLERY_ERROR", e.message, null) }
        }
    }

    private fun createImageFile(): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = cacheDir
        return File.createTempFile("owner_${timestamp}_", ".jpg", storageDir)
    }

    private fun getPathFromUri(uri: Uri): String? {
        return try {
            val projection = arrayOf(MediaStore.Images.Media.DATA)
            val cursor = contentResolver.query(uri, projection, null, null, null)
            cursor?.use {
                val columnIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                it.moveToFirst()
                it.getString(columnIndex)
            }
        } catch (e: Exception) {
            // Fallback for Android 10+ scoped storage
            copyUriToCache(uri)
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val file = File(cacheDir, "gallery_${timestamp}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    // ── RESULT ─────────────────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_CAMERA -> {
                if (resultCode == Activity.RESULT_OK) {
                    safeReply { it.success(cameraImagePath) }
                } else {
                    safeReply { it.success(null) }
                }
            }
            REQUEST_GALLERY -> {
                if (resultCode == Activity.RESULT_OK) {
                    val uri = data?.data
                    val path = if (uri != null) getPathFromUri(uri) else null
                    safeReply { it.success(path) }
                } else {
                    safeReply { it.success(null) }
                }
            }
        }
    }

    // Safe reply — prevents "Reply already submitted" crash
    private fun safeReply(block: (MethodChannel.Result) -> Unit) {
        val result = pendingResult
        pendingResult = null
        if (result != null) {
            try {
                block(result)
            } catch (e: Exception) {
                // Already replied, ignore
            }
        }
    }
}