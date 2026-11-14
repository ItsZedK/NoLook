package com.itszedk.nolook

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Android blocker: closes blocked apps, backs out of blocked sites, covers matching posts.
 * Also keeps the dart engine alive.
 */
class BlockerService : AccessibilityService() {
    companion object {
        fun isOn(context: Context): Boolean {
            val mine = ComponentName(context, BlockerService::class.java).flattenToString()
            val on = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
            return on.split(':').any { it.equals(mine, ignoreCase = true) }
        }

        /** address bar ids for common browsers, others go through [findAddress] */
        private val addressBars = mapOf(
            "com.android.chrome" to "com.android.chrome:id/url_bar",
            "com.chrome.beta" to "com.chrome.beta:id/url_bar",
            "com.microsoft.emmx" to "com.microsoft.emmx:id/url_bar",
            "com.brave.browser" to "com.brave.browser:id/url_bar",
            "com.opera.browser" to "com.opera.browser:id/url_field",
            "org.mozilla.firefox" to "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
            "com.sec.android.app.sbrowser" to "com.sec.android.app.sbrowser:id/location_bar_edit_text",
            "com.duckduckgo.mobile.android" to "com.duckduckgo.mobile.android:id/omnibarTextInput",
        )
    }

    private val main = Handler(Looper.getMainLooper())
    private lateinit var covers: Covers
    private var lastBlocked = ""
    private var lastBlockedAt = 0L

    override fun onServiceConnected() {
        Rules.load(this)
        NoLookEngine.get(this)
        covers = Covers(this)
        Notices.blockerBack(this)
        NoLookEngine.send("blocker", mapOf("on" to true))
    }

    override fun onUnbind(intent: Intent?): Boolean {
        // service got turned off, notify
        Notices.blockerOff(this)
        NoLookEngine.send("blocker", mapOf("on" to false))
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) {
            // could be one of our own cover windows, rescan (scan drops covers on our own screen)
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && ::covers.isInitialized) covers.recheck()
            return
        }
        if (pkg == "com.android.systemui") return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            Rules.blockForApp(pkg)?.let { block ->
                closeApp(pkg, block)
                return
            }
        }
        if (isBrowser(pkg) && checkAddress(pkg)) return
        covers.onEvent(event, pkg)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (::covers.isInitialized) covers.clear()
        super.onDestroy()
    }

    private fun once(key: String): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (key == lastBlocked && now - lastBlockedAt < 2500) return false
        lastBlocked = key
        lastBlockedAt = now
        return true
    }

    private fun closeApp(pkg: String, block: RuleBlock) {
        covers.clear()
        if (!once("app:$pkg")) {
            // closing app still sends events for a bit, re-check once instead of hitting home again
            main.removeCallbacks(recheck)
            recheckPkg = pkg
            main.postDelayed(recheck, 1200)
            return
        }
        performGlobalAction(GLOBAL_ACTION_HOME)
        NoLookEngine.send("blockedApp", mapOf("id" to pkg, "name" to block.apps[pkg.lowercase()], "blockId" to block.id))
        showNoLook()
    }

    private var recheckPkg = ""
    private val recheck = Runnable {
        val front = rootInActiveWindow?.packageName?.toString()
        if (front == recheckPkg && Rules.blockForApp(recheckPkg) != null) performGlobalAction(GLOBAL_ACTION_HOME)
    }

    private val browserWords = listOf("browser", "firefox", "mozilla", "chrome", "opera", "brave", "vivaldi", "duckduckgo", "kiwi")

    private fun isBrowser(pkg: String) = addressBars.containsKey(pkg) || browserWords.any { pkg.contains(it) }

    /** back out of a blocked site, true if it did */
    private fun checkAddress(pkg: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val url = findAddress(root, pkg) ?: return false
        val (block, rule) = Rules.blockForUrl(url) ?: return false
        performGlobalAction(GLOBAL_ACTION_BACK)
        covers.clear()
        if (once("site:${rule.text}")) {
            // use the rule text, not the full url
            NoLookEngine.send("blockedSite", mapOf("site" to rule.text.take(80), "blockId" to block.id))
            showNoLook()
        }
        return true
    }

    /** url-looking text only, not search terms */
    private fun asAddress(text: CharSequence?): String? {
        val t = text?.toString()?.trim() ?: return null
        if (t.length < 4 || t.contains(' ') || !t.contains('.')) return null
        return if (SiteRule.normalize(t) != null) t else null
    }

    private fun firstWord(text: CharSequence?): String? =
        text?.toString()?.trim()?.substringBefore(' ')?.trimEnd('.', ',', ';')

    /** current url or null (also null while typing) */
    private fun findAddress(root: AccessibilityNodeInfo, pkg: String): String? {
        addressBars[pkg]?.let { id ->
            root.findAccessibilityNodeInfosByViewId(id).firstOrNull()?.let { bar ->
                // typing, skip
                if (bar.isFocused) return null
                return asAddress(bar.text) ?: asAddress(bar.contentDescription)
            }
        }
        // fallback: url-looking text in the browser's bars, not the page (links in posts don't count)
        val height = resources.displayMetrics.heightPixels
        val stack = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        var seen = 0
        var named: String? = null
        var edge: String? = null
        val r = android.graphics.Rect()
        while (stack.isNotEmpty() && seen < 600) {
            val n = stack.removeFirst()
            seen++
            val cls = n.className?.toString() ?: ""
            if (cls.contains("WebView") || cls.contains("GeckoView") || cls.contains("EngineView")) continue
            val id = n.viewIdResourceName?.lowercase() ?: ""
            val isBar = id.contains("url") || id.contains("location_bar") || id.contains("address") || id.contains("toolbar")
            // firefox puts "url. Search or enter address" in the bar, take the first word
            val found = asAddress(n.text) ?: asAddress(n.contentDescription) ?: if (isBar) asAddress(firstWord(n.contentDescription)) else null
            if (found != null) {
                // typing, skip
                if (n.isEditable && n.isFocused) return null
                n.getBoundsInScreen(r)
                // some show the short host + full url for a11y, take the longest
                if (isBar && found.length > (named?.length ?: 0)) named = found
                // bars are at the top or bottom
                else if ((r.bottom < height * .22 || r.top > height * .78) && found.length > (edge?.length ?: 0)) edge = found
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { stack.add(it) }
        }
        return named ?: edge
    }

    private fun showNoLook() {
        main.postDelayed({
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            )
        }, 250)
    }
}
