package me.hans0805.vocpass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class VocPassFirebaseMessagingService : FirebaseMessagingService() {
  companion object {
    private const val CLASS_STATUS_CHANNEL_ID = "vocpass_class_status"
    private const val CLASS_STATUS_NOTIFICATION_ID = 5566
  }

  override fun onMessageReceived(message: RemoteMessage) {
    val data = message.data
    if (data.isEmpty()) return

    val currentLabel = data["currentLabel"] ?: return
    val currentTime = data["currentTime"] ?: "--:-- ~ --:--"
    val currentCountdown = data["currentCountdown"] ?: "--:--:--"
    val nextLabel = data["nextLabel"] ?: "下節課：無"
    val nextTime = data["nextTime"] ?: "--:-- ~ --:--"
    val nextCountdown = data["nextCountdown"] ?: "--:--:--"

    createClassStatusChannel()
    showClassStatusNotification(
      currentLabel = currentLabel,
      currentTime = currentTime,
      currentCountdown = currentCountdown,
      nextLabel = nextLabel,
      nextTime = nextTime,
      nextCountdown = nextCountdown,
    )
  }

  private fun createClassStatusChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

    val notificationManager =
      getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (notificationManager.getNotificationChannel(CLASS_STATUS_CHANNEL_ID) != null) {
      return
    }

    val channel = NotificationChannel(
      CLASS_STATUS_CHANNEL_ID,
      getString(R.string.class_status_channel_name),
      NotificationManager.IMPORTANCE_LOW,
    ).apply {
      description = getString(R.string.class_status_channel_description)
      setShowBadge(false)
      lockscreenVisibility = Notification.VISIBILITY_PUBLIC
    }

    notificationManager.createNotificationChannel(channel)
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
}
