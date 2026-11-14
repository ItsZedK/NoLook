package com.itszedk.nolook

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.net.HttpURLConnection
import java.net.URL

/**
 * Downloads the apk from github and hands it to the package installer (always asks, not a store app).
 */
object Updater {
    /** [done] gets null once the prompt is up, else an error */
    fun install(context: Context, url: String, progress: (Double) -> Unit, done: (String?) -> Unit) {
        Thread {
            val error = runCatching {
                val installer = context.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
                    setAppPackageName(context.packageName)
                    if (Build.VERSION.SDK_INT >= 31) setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
                }
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    var conn = URL(url).openConnection() as HttpURLConnection
                    // follow redirects
                    var hops = 0
                    while (conn.responseCode in 300..399 && hops++ < 5) {
                        val next = conn.getHeaderField("Location")
                        conn.disconnect()
                        conn = URL(URL(url), next).openConnection() as HttpURLConnection
                    }
                    if (conn.responseCode != 200) error("download failed (${conn.responseCode})")
                    val total = conn.contentLengthLong
                    session.openWrite("NoLook.apk", 0, if (total > 0) total else -1).use { out ->
                        conn.inputStream.use { input ->
                            val buf = ByteArray(64 * 1024)
                            var got = 0L
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                out.write(buf, 0, n)
                                got += n
                                if (total > 0) progress(got.toDouble() / total)
                            }
                        }
                        session.fsync(out)
                    }
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                    val status = PendingIntent.getBroadcast(context, id, Intent(context, UpdateStatus::class.java), flags)
                    session.commit(status.intentSender)
                }
            }.exceptionOrNull()
            done(error?.message ?: error?.toString())
        }.start()
    }
}

/** install status, shows the confirm prompt when needed */
class UpdateStatus : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999) == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION")
            val confirm = (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java) else intent.getParcelableExtra(Intent.EXTRA_INTENT)) ?: return
            context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
