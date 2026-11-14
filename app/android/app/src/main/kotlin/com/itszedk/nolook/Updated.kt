package com.itszedk.nolook

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After an update android can kill the blocker without telling it, so warn if it's off.
 */
class Updated : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        Rules.load(context)
        if (!BlockerService.isOn(context)) Notices.blockerOff(context)
    }
}
