package com.example.annoto

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

class OexEngineBridge(private val context: Context) {
    companion object {
        private const val ENGINE_ACTION = "intent.chess.provider.ENGINE"
        private const val METADATA_AUTHORITY = "chess.provider.engine.authority"
        private const val METADATA_NAME = "chess.provider.engine.name"
        private const val ENGINE_BINARY_NAME = "chess_engine"
        private const val STOCKFISH_PACKAGE = "com.stockfish141"
        private const val TAG = "OexEngineBridge"
    }

    private var engineProcess: Process? = null
    private var engineInputStream: java.io.InputStream? = null
    private var engineOutputStream: java.io.OutputStream? = null
    private var eventSink: EventChannel.EventSink? = null
    private val pendingOutput = mutableListOf<String>()
    private val outputBuffer = mutableListOf<String>()
    private var engineThread: Thread? = null
    private var running = false

    private val mainHandler = Handler(Looper.getMainLooper())

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null && pendingOutput.isNotEmpty()) {
            pendingOutput.forEach { sink.success(it) }
            pendingOutput.clear()
        }
    }

    private fun emitOutput(line: String) {
        Log.d(TAG, "engine <= $line")
        synchronized(outputBuffer) {
            outputBuffer.add(line)
        }
        val sink = eventSink
        if (sink != null) {
            sink.success(line)
        } else {
            pendingOutput.add(line)
        }
    }

    fun drainOutput(): List<String> {
        synchronized(outputBuffer) {
            val lines = outputBuffer.toList()
            outputBuffer.clear()
            return lines
        }
    }

    data class EngineInfo(
        val name: String,
        val packageName: String,
        val authority: String?
    )

    fun listEngines(): List<Map<String, String>> {
        val intent = Intent(ENGINE_ACTION)
        val pm = context.packageManager
        // OEX engines are registered as activities with provider metadata
        val activities: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(PackageManager.GET_META_DATA.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, PackageManager.GET_META_DATA)
        }
        Log.d(TAG, "listEngines found ${activities.size} activities for action $ENGINE_ACTION")

        val engines = mutableListOf<EngineInfo>()
        activities.forEach { info ->
            try {
                val label = info.loadLabel(pm).toString()
                val pkg = info.activityInfo.packageName
                val authority = info.activityInfo.metaData?.getString(METADATA_AUTHORITY)
                Log.d(TAG, "  -> $pkg / ${info.activityInfo.name} (authority: $authority)")
                engines.add(
                    EngineInfo(
                        name = label,
                        packageName = pkg,
                        authority = authority
                    )
                )
            } catch (e: Exception) {
                val pkg = info.activityInfo?.packageName
                Log.e(TAG, "Failed to read engine metadata for $pkg", e)
                if (pkg != null) {
                    engines.add(
                        EngineInfo(
                            name = pkg,
                            packageName = pkg,
                            authority = null
                        )
                    )
                }
            }
        }

        return engines.map { engine ->
            mapOf(
                "name" to engine.name,
                "packageName" to engine.packageName,
            )
        }
    }

    fun start(packageName: String, onSuccess: () -> Unit, onFailure: (String) -> Unit) {
        stop() // Stop any existing engine

        val pm = context.packageManager
        val intent = Intent(ENGINE_ACTION).apply { setPackage(packageName) }
        val resolveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(PackageManager.GET_META_DATA.toLong())).firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, PackageManager.GET_META_DATA).firstOrNull()
        }

        if (resolveInfo == null) {
            onFailure("Engine app not found: $packageName")
            return
        }

        val engineFile = getEngineFromApp(packageName, onFailure)

        if (engineFile == null) return

        // Start the engine as a local process
        try {
            val processBuilder = ProcessBuilder(engineFile.absolutePath)
            processBuilder.redirectErrorStream(true)
            val process = processBuilder.start()

            engineProcess = process
            engineInputStream = process.inputStream
            engineOutputStream = process.outputStream
            running = true

            // Start reading output in background thread
            engineThread = Thread {
                val buffer = ByteArray(1024)
                val reader = engineInputStream
                while (running && reader != null) {
                    try {
                        val bytesRead = reader.read(buffer)
                        if (bytesRead > 0) {
                            val lines = String(buffer, 0, bytesRead).split("\n")
                            for (line in lines) {
                                if (line.isNotBlank()) {
                                    mainHandler.post {
                                            emitOutput(line.trim())
                                    }
                                }
                            }
                        } else if (bytesRead == -1) {
                            // EOF
                            break
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error reading engine output", e)
                        break
                    }
                }
            }
            engineThread?.start()

            onSuccess()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start engine process", e)
            onFailure("Failed to start engine: ${e.message}")
        }
    }

    private fun getEngineFromApp(
        packageName: String,
        onFailure: (String) -> Unit
    ): File? {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
            val nativeLibraryDir = appInfo.nativeLibraryDir

            val libDir = File(nativeLibraryDir)
            if (!libDir.exists()) {
                onFailure("Cannot access native library directory for $packageName")
                return null
            }

            val engineLib = libDir.listFiles { f ->
                f.name.endsWith(".so") && f.name.contains("stockfish", ignoreCase = true)
            }?.firstOrNull()

            val engineFile = engineLib ?: libDir.listFiles { f ->
                f.name.endsWith(".so") && f.length() > 100000
            }?.firstOrNull()

            if (engineFile == null) {
                onFailure("No engine library found in $packageName")
                return null
            }

            Log.d(TAG, "Using native engine: ${engineFile.absolutePath}")
            engineFile
        } catch (e: Exception) {
            Log.e(TAG, "Error getting engine from app", e)
            onFailure("Failed to get engine: ${e.message}")
            null
        }
    }

    private fun copyEngineBinary(
        authority: String,
        packageName: String,
        onFailure: (String) -> Unit
    ): File? {
        return try {
            val providerUri = Uri.parse("content://$authority/engine")
            val cursor = context.contentResolver.query(
                providerUri,
                null,
                null,
                null,
                null
            )?.use { it }

            if (cursor == null || !cursor.moveToFirst()) {
                // Try alternative URI patterns
                val altUri = Uri.parse("content://$authority")
                val altCursor = context.contentResolver.query(
                    altUri,
                    null,
                    null,
                    null,
                    null
                )?.use { it }

                if (altCursor == null) {
                    onFailure("Cannot access engine provider")
                    return null
                }

                copyEngineFromCursor(altCursor, packageName, onFailure)
            } else {
                copyEngineFromCursor(cursor, packageName, onFailure)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error copying engine binary", e)
            onFailure("Failed to copy engine: ${e.message}")
            null
        }
    }

    private fun copyEngineFromCursor(
        cursor: Cursor,
        packageName: String,
        onFailure: (String) -> Unit
    ): File? {
        return try {
            val engineDir = File(context.filesDir, "engines")
            if (!engineDir.exists()) {
                engineDir.mkdirs()
            }

            // Use package name as the binary name to avoid conflicts
            val engineFile = File(engineDir, "${ENGINE_BINARY_NAME}_${packageName.replace('.', '_')}")

            // Check if we already have this engine copied
            if (engineFile.exists() && engineFile.length() > 0) {
                Log.d(TAG, "Using cached engine: ${engineFile.absolutePath}")
                engineFile.setExecutable(true)
                return engineFile
            }

            // Get the engine binary from the provider
            val providerUri = Uri.parse("content://${cursor.getString(0)}/engine")
                ?: Uri.parse("content://${packageName}/engine")

            val inputStream = context.contentResolver.openInputStream(providerUri)
                ?: run {
                    // Try default URI
                    val defaultUri = Uri.parse("content://$packageName/$ENGINE_BINARY_NAME")
                    context.contentResolver.openInputStream(defaultUri)
                }
                ?: run {
                    // Try to get file descriptor from cursor
                    val fdIndex = cursor.getColumnIndex("_data")
                    if (fdIndex >= 0) {
                        val path = cursor.getString(fdIndex)
                        if (path != null) {
                            File(path).inputStream()
                        } else null
                    } else null
                }

            if (inputStream == null) {
                // Try the standard OEX approach - query for engine file
                val engineUri = Uri.parse("content://$packageName/engine")
                val engineStream = context.contentResolver.openInputStream(engineUri)
                if (engineStream != null) {
                    engineStream.use { input ->
                        FileOutputStream(engineFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    engineFile.setExecutable(true)
                    Log.d(TAG, "Copied engine to: ${engineFile.absolutePath}")
                    return engineFile
                } else {
                    onFailure("Cannot read engine binary from provider")
                    return null
                }
            }

            inputStream.use { input ->
                FileOutputStream(engineFile).use { output ->
                    input.copyTo(output)
                }
            }

            engineFile.setExecutable(true)
            Log.d(TAG, "Copied engine to: ${engineFile.absolutePath}")
            engineFile
        } catch (e: Exception) {
            Log.e(TAG, "Error copying engine from cursor", e)
            onFailure("Failed to copy engine: ${e.message}")
            null
        }
    }

    fun send(command: String) {
        if (!running || command.isEmpty()) return
        val outputStream = engineOutputStream ?: return
        try {
            Log.d(TAG, "engine => $command")
            outputStream.write((command + "\n").toByteArray())
            outputStream.flush()
        } catch (e: Exception) {
            Log.e(TAG, "Error sending command", e)
        }
    }

    fun stop() {
        running = false

        // Send quit command
        send("quit")

        // Wait briefly for process to exit
        engineProcess?.waitFor(100, TimeUnit.MILLISECONDS)
        engineProcess?.destroy()

        // Clean up resources
        engineInputStream?.close()
        engineOutputStream?.close()
        engineThread?.interrupt()

        engineProcess = null
        engineInputStream = null
        engineOutputStream = null
        engineThread = null
        eventSink = null
        pendingOutput.clear()
        synchronized(outputBuffer) {
            outputBuffer.clear()
        }
    }
}
