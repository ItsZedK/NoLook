package com.itszedk.nolook

import android.app.Activity
import android.content.Context
import java.lang.ref.WeakReference
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** attaches to the shared engine, which outlives the activity */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = NoLookEngine.get(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    companion object {
        /** current activity, for permission prompts */
        var current = WeakReference<Activity>(null)
    }

    override fun onResume() {
        super.onResume()
        current = WeakReference(this)
    }

    override fun onPause() {
        if (current.get() === this) current = WeakReference(null)
        super.onPause()
    }

    override fun onPostResume() {
        super.onPostResume()
        // engine starts before the activity (the service starts it), so flutter's back setup
        // never reached us. without this, back closes the app
        setFrameworkHandlesBack(true)
    }
}
