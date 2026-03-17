package com.example.android

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channel = "vocpass/dynamic_island"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "isSupported" -> result.success(isDynamicIslandSupported())
          else -> result.notImplemented()
        }
      }
  }

  private fun isDynamicIslandSupported(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
    val insets = window.decorView.rootWindowInsets ?: return false
    val cutout = insets.displayCutout ?: return false
    return cutout.boundingRects.isNotEmpty()
  }
}
