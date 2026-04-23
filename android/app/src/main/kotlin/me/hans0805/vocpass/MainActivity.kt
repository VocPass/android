package me.hans0805.vocpass

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
  companion object {
    const val PUSH_CHANNEL_ID = "vocpass_push"
    const val CLASS_STATUS_CHANNEL_ID = "vocpass_class_status"
    const val CLASS_STATUS_NOTIFICATION_ID = 5566
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
          "showOngoingPlaceholderNotification" -> {
            showOngoingPlaceholderNotification()
            result.success(null)
          }
          "showClassStatusNotification" -> {
            val args = call.arguments as? Map<*, *>
            if (args == null) {
              result.error("invalid_args", "Missing notification args", null)
              return@setMethodCallHandler
            }

            showClassStatusNotification(
              currentLabel = args["currentLabel"]?.toString().orEmpty(),
              currentTime = args["currentTime"]?.toString().orEmpty(),
              currentCountdown = args["currentCountdown"]?.toString().orEmpty(),
              nextLabel = args["nextLabel"]?.toString().orEmpty(),
              nextTime = args["nextTime"]?.toString().orEmpty(),
              nextCountdown = args["nextCountdown"]?.toString().orEmpty(),
            )
            result.success(null)
          }
          "cancelClassStatusNotification" -> {
            cancelClassStatusNotification()
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

  private fun createNotificationChannel() {
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

    if (notificationManager.getNotificationChannel(CLASS_STATUS_CHANNEL_ID) == null) {
      val classStatusChannel = NotificationChannel(
        CLASS_STATUS_CHANNEL_ID,
        getString(R.string.class_status_channel_name),
        NotificationManager.IMPORTANCE_LOW,
      ).apply {
        description = getString(R.string.class_status_channel_description)
        setShowBadge(false)
        lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
      }
      notificationManager.createNotificationChannel(classStatusChannel)
    }
  }

  private fun showClassStatusNotification(
    currentLabel: String,
    currentTime: String,
    currentCountdown: String,
    nextLabel: String,
    nextTime: String,
    nextCountdown: String,
  ) {
    val launchIntent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val smallRemoteViews = RemoteViews(packageName, R.layout.notification_class_status_small).apply {
      setTextViewText(R.id.title, "這節課")
      setTextViewText(R.id.current_label, currentLabel)
      setTextViewText(R.id.current_time_countdown, "$currentTime ｜ 倒數 $currentCountdown")
    }

    val bigRemoteViews = RemoteViews(packageName, R.layout.notification_class_status_big).apply {
      setTextViewText(R.id.big_title, "課程動態")
      setTextViewText(R.id.big_current_title, "這節課")
      setTextViewText(R.id.big_current_label, currentLabel)
      setTextViewText(R.id.big_current_time, "時間：$currentTime")
      setTextViewText(R.id.big_current_countdown, "倒數：$currentCountdown")
      setTextViewText(R.id.big_next_title, "下節課")
      setTextViewText(R.id.big_next_label, nextLabel)
      setTextViewText(R.id.big_next_time, "時間：$nextTime")
      setTextViewText(R.id.big_next_countdown, "倒數：$nextCountdown")
    }

    val notification = NotificationCompat.Builder(this, CLASS_STATUS_CHANNEL_ID)
      .setSmallIcon(R.mipmap.launcher_icon)
      .setContentTitle("課程動態")
      .setContentText("$currentLabel｜倒數 $currentCountdown")
      .setStyle(NotificationCompat.DecoratedCustomViewStyle())
      .setCustomContentView(smallRemoteViews)
      .setCustomBigContentView(bigRemoteViews)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setOnlyAlertOnce(true)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(pendingIntent)
      .build()

    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(CLASS_STATUS_NOTIFICATION_ID, notification)
  }

  private fun showOngoingPlaceholderNotification() {
    val launchIntent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val notification = NotificationCompat.Builder(this, CLASS_STATUS_CHANNEL_ID)
      .setSmallIcon(R.mipmap.launcher_icon)
      .setContentTitle("課程動態")
      .setContentText("通知已啟用，正在載入課程資料...")
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setOnlyAlertOnce(true)
      .setOngoing(true)
      .setAutoCancel(false)
      .setContentIntent(pendingIntent)
      .build()

    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(CLASS_STATUS_NOTIFICATION_ID, notification)
  }

  private fun cancelClassStatusNotification() {
    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.cancel(CLASS_STATUS_NOTIFICATION_ID)
  }
}
