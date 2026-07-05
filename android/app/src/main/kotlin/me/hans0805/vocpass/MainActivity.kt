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
    createPushChannel()
    ClassStatusNotifier.ensureChannel(this)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "isSupported" -> result.success(isDynamicIslandSupported())
          "showOngoingPlaceholderNotification" -> {
            ClassStatusNotifier.showPlaceholder(this)
            result.success(null)
          }
          "showClassStatusNotification" -> {
            val args = call.arguments as? Map<*, *>
            if (args == null) {
              result.error("invalid_args", "Missing notification args", null)
              return@setMethodCallHandler
            }

            ClassStatusNotifier.show(
              this,
              ClassStatusNotifier.ClassStatus(
                currentLabel = args["currentLabel"]?.toString().orEmpty(),
                currentTime = args["currentTime"]?.toString().orEmpty(),
                currentCountdown = args["currentCountdown"]?.toString().orEmpty(),
                nextLabel = args["nextLabel"]?.toString().orEmpty(),
                nextTime = args["nextTime"]?.toString().orEmpty(),
                nextCountdown = args["nextCountdown"]?.toString().orEmpty(),
                currentRemainingSec = (args["currentRemainingSec"] as? Number)?.toLong() ?: -1,
                nextRemainingSec = (args["nextRemainingSec"] as? Number)?.toLong() ?: -1,
              ),
            )
            result.success(null)
          }
          "cancelClassStatusNotification" -> {
            ClassStatusNotifier.cancel(this)
            result.success(null)
          }
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

  private fun createPushChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (notificationManager.getNotificationChannel(PUSH_CHANNEL_ID) == null) {
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
}
