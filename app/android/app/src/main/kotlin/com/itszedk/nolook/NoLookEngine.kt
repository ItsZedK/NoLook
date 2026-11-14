package com.itszedk.nolook

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Single shared dart engine, started by the service or the activity (whichever's first).
 * Keeps schedules/locks running with the ui closed, and no two engines writing the same files.
 */
object NoLookEngine {
    private const val ID = "nolook"
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun get(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        val engine = FlutterEngine(app)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "nolook/android").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "rules" -> {
                        Rules.update(app, call.arguments as String)
                        result.success(null)
                    }
                    "status" -> result.success(mapOf("blocker" to BlockerService.isOn(app)))
                    "openBlockerSettings" -> {
                        openBlockerSettings(app)
                        result.success(null)
                    }
                    "openAppInfo" -> {
                        app.startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${app.packageName}"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "openUrl" -> {
                        runCatching {
                            app.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url"))).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(null)
                    }
                    "installUpdate" -> {
                        Updater.install(app, call.argument<String>("url")!!,
                            progress = { p -> send("updateProgress", mapOf("value" to p)) },
                            done = { err -> main.post { result.success(err) } })
                    }
                    "saveToDownloads" -> result.success(
                        runCatching { saveToDownloads(app, call.argument<String>("name")!!, call.argument<String>("text")!!) }.getOrNull(),
                    )
                    "apps" -> result.success(installedApps(app))
                    "notify" -> {
                        Notices.post(app, call.argument<String>("title")!!, call.argument<String>("text")!!)
                        result.success(null)
                    }
                    "askNotifications" -> {
                        Notices.ask(MainActivity.current.get(), call.argument<Boolean>("force") == true)
                        result.success(null)
                    }
                    "notificationsAllowed" -> result.success(Notices.allowed(app))
                    else -> result.notImplemented()
                }
            }
        }
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }

    /** blocker events to dart */
    fun send(method: String, args: Map<String, Any?>) {
        main.post { channel?.invokeMethod(method, args) }
    }

    /** our a11y settings page, or the list as fallback */
    private fun openBlockerSettings(context: Context) {
        val component = ComponentName(context, BlockerService::class.java).flattenToString()
        val direct = Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS")
            .putExtra(Intent.EXTRA_COMPONENT_NAME, component)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(direct)
        } catch (_: Exception) {
            context.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** launcher apps */
    /** save to Downloads, returns the path */
    private fun saveToDownloads(context: Context, name: String, text: String): String {
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Downloads.DISPLAY_NAME, name)
                put(android.provider.MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
            }
            val uri = context.contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: error("no Downloads")
            context.contentResolver.openOutputStream(uri)!!.use { it.write(text.toByteArray()) }
            return "Downloads/$name"
        }
        // older android: app folder
        val dir = context.getExternalFilesDir(null) ?: context.filesDir
        java.io.File(dir, name).writeText(text)
        return java.io.File(dir, name).path
    }

    private fun installedApps(context: Context): List<Map<String, String>> {
        val pm = context.packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(launcher, PackageManager.MATCH_ALL)
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != context.packageName }
            .distinctBy { it.first }
            .sortedBy { it.second.lowercase() }
            .map { mapOf("id" to it.first, "name" to it.second) }
    }
}
