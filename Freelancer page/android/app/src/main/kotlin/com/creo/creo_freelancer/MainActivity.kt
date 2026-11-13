package com.creo.creo_freelancer

import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterShellArgs

/**
 * The launcher activity is exported, so any app on the device can start it with extras.
 * In release builds, ignore the start route, Dart entrypoint arguments and engine flags
 * that would otherwise be read from that intent. Debug builds keep them for `flutter run`.
 */
class MainActivity : FlutterActivity() {
    private val debuggable: Boolean
        get() = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    override fun getInitialRoute(): String? = if (debuggable) super.getInitialRoute() else null

    override fun getDartEntrypointArgs(): List<String>? = if (debuggable) super.getDartEntrypointArgs() else null

    override fun getFlutterShellArgs(): FlutterShellArgs =
        if (debuggable) super.getFlutterShellArgs() else FlutterShellArgs(arrayOf<String>())
}
