package com.example.annoto

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannel = "com.example.annoto/update"
    private val oexMethodChannel = "app/oex_engine"
    private val oexEventChannel = "app/oex_engine_output"
    private val foregroundServiceChannel = "app/foreground_service"
    private val pgnIntentEventChannel = "app/pgn_intent"

    private val oexBridge by lazy { OexEngineBridge(this) }
    private var pendingPgnContent: String? = null
    private var pgnEventSink: EventChannel.EventSink? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val content = extractPgnFromIntent(intent) ?: return
        val sink = pgnEventSink
        if (sink != null) {
            sink.success(content)
        } else {
            pendingPgnContent = content
        }
    }

    private fun extractPgnFromIntent(intent: Intent): String? {
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                readUriContent(uri)
            }
            Intent.ACTION_SEND -> {
                intent.getStringExtra(Intent.EXTRA_TEXT)
            }
            Intent.ACTION_PROCESS_TEXT -> {
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            }
            else -> null
        }
    }

    private fun readUriContent(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                stream.bufferedReader(Charsets.UTF_8).readText()
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        extractPgnFromIntent(intent)?.let { pendingPgnContent = it }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, pgnIntentEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pgnEventSink = events
                    pendingPgnContent?.let { content ->
                        events?.success(content)
                        pendingPgnContent = null
                    }
                }
                override fun onCancel(arguments: Any?) {
                    pgnEventSink = null
                }
            })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                0,
            )
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(can)
                    }
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                )
                            )
                        }
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            File(path),
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, oexMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listEngines" -> {
                        result.success(oexBridge.listEngines())
                    }
                    "start" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg == null) {
                            result.error("INVALID_ARG", "Missing packageName", null)
                            return@setMethodCallHandler
                        }
                        oexBridge.start(
                            packageName = pkg,
                            onSuccess = { result.success(null) },
                            onFailure = { msg -> result.error("BIND_FAILED", msg, null) },
                        )
                    }
                    "send" -> {
                        val command = call.argument<String>("command") ?: ""
                        oexBridge.send(command)
                        result.success(null)
                    }
                    "drainOutput" -> {
                        result.success(oexBridge.drainOutput())
                    }
                    "stop" -> {
                        oexBridge.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundServiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, AnalysisForegroundService::class.java).apply {
                            action = AnalysisForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        val intent = Intent(this, AnalysisForegroundService::class.java).apply {
                            action = AnalysisForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, oexEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    oexBridge.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    oexBridge.setEventSink(null)
                }
            })
    }

    override fun onDestroy() {
        oexBridge.stop()
        stopService(Intent(this, AnalysisForegroundService::class.java))
        super.onDestroy()
    }
}
