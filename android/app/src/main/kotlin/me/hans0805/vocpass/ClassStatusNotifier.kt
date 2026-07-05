package me.hans0805.vocpass

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/**
 * 常駐「課程動態」通知的唯一組裝點。
 *
 * MainActivity（App 開著時，Dart 每秒透過 MethodChannel 更新倒數）與
 * VocPassFirebaseMessagingService（App 被關掉時，由後端 FCM data message 觸發）
 * 都呼叫這裡，確保兩條路徑產生的通知外觀完全一致，不會各自漂移。
 */
object ClassStatusNotifier {
  const val CHANNEL_ID = "vocpass_class_status"
  const val NOTIFICATION_ID = 5566

  data class ClassStatus(
    val currentLabel: String,
    val currentTime: String,
    val currentCountdown: String,
    val nextLabel: String,
    val nextTime: String,
    val nextCountdown: String,
    // 距離「這節課結束 / 下節課開始」的剩餘秒數；-1 代表無（無上課 / 無下節課）。
    // 有值時用系統原生 Chronometer 自動每秒倒數，App 關著也會跳，不必重送 FCM。
    val currentRemainingSec: Long = -1,
    val nextRemainingSec: Long = -1,
  )

  /** 把倒數欄位綁成自動跳秒的 Chronometer；剩餘秒數 < 0 時退回靜態文字。 */
  private fun RemoteViews.bindCountdown(
    chronometerId: Int,
    staticTextId: Int,
    remainingSec: Long,
    fallbackText: String,
  ) {
    // setChronometerCountDown 需要 API 24+；更舊的機退回靜態文字。
    if (remainingSec >= 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      setViewVisibility(chronometerId, View.VISIBLE)
      setViewVisibility(staticTextId, View.GONE)
      // Chronometer 的 base 相對 SystemClock.elapsedRealtime()；倒數模式下
      // 顯示 = base - now，所以把「還剩幾秒」加到現在即為 base。
      val base = SystemClock.elapsedRealtime() + remainingSec * 1000L
      setChronometerCountDown(chronometerId, true)
      setChronometer(chronometerId, base, null, true)
    } else {
      setViewVisibility(chronometerId, View.GONE)
      setViewVisibility(staticTextId, View.VISIBLE)
      setTextViewText(staticTextId, fallbackText)
    }
  }

  fun ensureChannel(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

    val notificationManager =
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (notificationManager.getNotificationChannel(CHANNEL_ID) != null) return

    val channel = NotificationChannel(
      CHANNEL_ID,
      context.getString(R.string.class_status_channel_name),
      NotificationManager.IMPORTANCE_LOW,
    ).apply {
      description = context.getString(R.string.class_status_channel_description)
      setShowBadge(false)
      lockscreenVisibility = Notification.VISIBILITY_PUBLIC
    }
    notificationManager.createNotificationChannel(channel)
  }

  fun show(context: Context, status: ClassStatus) {
    ensureChannel(context)

    val launchIntent = Intent(context, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val pendingIntent = PendingIntent.getActivity(
      context,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    // 沒有正在上的課（下課中 / 今日已結束）時，這節課區塊只留 label，
    // 時間與倒數整排隱藏，資訊交給下方「下節課」呈現。
    val hasCurrentClass = status.currentTime.isNotBlank()

    val smallRemoteViews =
      RemoteViews(context.packageName, R.layout.notification_class_status_small).apply {
        setTextViewText(R.id.title, "這節課")
        setTextViewText(R.id.current_label, status.currentLabel)
        if (hasCurrentClass) {
          setViewVisibility(R.id.current_time_row, View.VISIBLE)
          setTextViewText(R.id.current_time, "${status.currentTime} ｜ 倒數 ")
          bindCountdown(
            R.id.current_countdown,
            R.id.current_countdown_static,
            status.currentRemainingSec,
            status.currentCountdown,
          )
        } else {
          setViewVisibility(R.id.current_time_row, View.GONE)
        }
      }

    val bigRemoteViews =
      RemoteViews(context.packageName, R.layout.notification_class_status_big).apply {
        setTextViewText(R.id.big_title, "課程動態")
        setTextViewText(R.id.big_current_title, "這節課")
        setTextViewText(R.id.big_current_label, status.currentLabel)
        if (hasCurrentClass) {
          setViewVisibility(R.id.big_current_time, View.VISIBLE)
          setViewVisibility(R.id.big_current_countdown_row, View.VISIBLE)
          setTextViewText(R.id.big_current_time, "時間：${status.currentTime}")
          bindCountdown(
            R.id.big_current_countdown,
            R.id.big_current_countdown_static,
            status.currentRemainingSec,
            status.currentCountdown,
          )
        } else {
          setViewVisibility(R.id.big_current_time, View.GONE)
          setViewVisibility(R.id.big_current_countdown_row, View.GONE)
        }
        setTextViewText(R.id.big_next_title, "下節課")
        setTextViewText(R.id.big_next_label, status.nextLabel)
        setTextViewText(R.id.big_next_time, "時間：${status.nextTime}")
        bindCountdown(
          R.id.big_next_countdown,
          R.id.big_next_countdown_static,
          status.nextRemainingSec,
          status.nextCountdown,
        )
      }

    // 摺疊時的單行摘要：上課中→「這節課｜倒數」；下課中→「下課中｜下節 xxx 倒數」。
    val contentText = if (hasCurrentClass) {
      "${status.currentLabel}｜倒數 ${status.currentCountdown}"
    } else if (status.nextRemainingSec >= 0) {
      "${status.currentLabel}｜下節 ${status.nextLabel}"
    } else {
      status.currentLabel
    }

    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
      .setSmallIcon(R.mipmap.launcher_icon)
      .setContentTitle("課程動態")
      .setContentText(contentText)
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
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(NOTIFICATION_ID, notification)
  }

  fun showPlaceholder(context: Context) {
    ensureChannel(context)

    val launchIntent = Intent(context, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val pendingIntent = PendingIntent.getActivity(
      context,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
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
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(NOTIFICATION_ID, notification)
  }

  fun cancel(context: Context) {
    val notificationManager =
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.cancel(NOTIFICATION_ID)
  }
}
