package me.hans0805.vocpass

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  companion object {
    const val PUSH_CHANNEL_ID = "vocpass_push"
  }

  private val channel = "vocpass/dynamic_island"

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    createNotificationChannel()
  }

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

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val existingChannel = notificationManager.getNotificationChannel(PUSH_CHANNEL_ID)
    if (existingChannel != null) return

    val pushChannel = NotificationChannel(
      PUSH_CHANNEL_ID,
      getString(R.string.push_channel_name),
      NotificationManager.IMPORTANCE_HIGH,
    ).apply {
      description = getString(R.string.push_channel_description)
    }

    notificationManager.createNotificationChannel(pushChannel)
  }
}
