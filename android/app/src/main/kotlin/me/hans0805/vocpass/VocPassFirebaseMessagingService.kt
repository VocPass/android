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
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

class VocPassFirebaseMessagingService : FirebaseMessagingService() {
  companion object {
    private const val CLASS_STATUS_CHANNEL_ID = "vocpass_class_status"
    private const val CLASS_STATUS_NOTIFICATION_ID = 5566
  }

  override fun onMessageReceived(message: RemoteMessage) {
    val data = message.data
    if (data.isEmpty()) return

    val curriculumStr = data["curriculum"] ?: return
    try {
        val classStatus = parseCurriculumToClassStatus(curriculumStr)
        createClassStatusChannel()
        showClassStatusNotification(
            currentLabel = classStatus["currentLabel"] ?: "目前無上課",
            currentTime = classStatus["currentTime"] ?: "--:-- ~ --:--",
            currentCountdown = classStatus["currentCountdown"] ?: "00:00:00",
            nextLabel = classStatus["nextLabel"] ?: "下節課：無",
            nextTime = classStatus["nextTime"] ?: "--:-- ~ --:--",
            nextCountdown = classStatus["nextCountdown"] ?: "00:00:00",
        )
    } catch (e: Exception) {
        e.printStackTrace()
    }
  }

  private fun parseMinutes(timeStr: String): Int {
      try {
          val parts = timeStr.split(":")
          if (parts.size >= 2) {
              return parts[0].toInt() * 60 + parts[1].toInt()
          }
      } catch (e: Exception) {}
      return 0
  }

  private fun formatCountdown(totalSeconds: Int): String {
      val safeSeconds = kotlin.math.max(totalSeconds, 0)
      val hours = safeSeconds / 3600
      val minutes = (safeSeconds % 3600) / 60
      val seconds = safeSeconds % 60
      return String.format(Locale.getDefault(), "%02d:%02d:%02d", hours, minutes, seconds)
  }

  private fun parseCurriculumToClassStatus(jsonStr: String): Map<String, String> {
      val array = JSONArray(jsonStr)
      val classes = mutableListOf<JSONObject>()
      for (i in 0 until array.length()) {
          val item = array.optJSONObject(i)
          if (item != null) {
              classes.add(item)
          }
      }

      classes.sortBy { parseMinutes(it.optString("startTime", "")) }

      val cal = Calendar.getInstance()
      val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
      val nowSeconds = cal.get(Calendar.SECOND)

      var current: JSONObject? = null
      var nextClass: JSONObject? = null

      for (item in classes) {
          val startM = parseMinutes(item.optString("startTime", ""))
          val endM = parseMinutes(item.optString("endTime", ""))

          val startsBeforeNow = startM < nowMinutes || (startM == nowMinutes && nowSeconds >= 0)
          val endsAfterNow = endM > nowMinutes || (endM == nowMinutes && nowSeconds == 0)

          if (startsBeforeNow && endsAfterNow) {
              current = item
              continue
          }

          if (startM > nowMinutes || (startM == nowMinutes && nowSeconds == 0)) {
              nextClass = item
              break
          }
      }

      val result = mutableMapOf<String, String>()

      if (current != null) {
          val period = current.optString("period", "").trim()
          val subject = current.optString("subject", "").trim()
          val room = current.optString("room", "").trim()
          val startTime = current.optString("startTime", "").trim()
          val endTime = current.optString("endTime", "").trim()

          result["currentLabel"] = "$period $subject ($room)"
          result["currentTime"] = "$startTime ~ $endTime"

          val endCal = Calendar.getInstance()
          val endM = parseMinutes(endTime)
          endCal.set(Calendar.HOUR_OF_DAY, endM / 60)
          endCal.set(Calendar.MINUTE, endM % 60)
          endCal.set(Calendar.SECOND, 0)
          result["currentCountdown"] = formatCountdown(((endCal.timeInMillis - cal.timeInMillis) / 1000).toInt())
      } else {
          result["currentLabel"] = "目前無上課"
          result["currentTime"] = "--:-- ~ --:--"
          result["currentCountdown"] = "00:00:00"
      }

      if (nextClass != null) {
          val period = nextClass.optString("period", "").trim()
          val subject = nextClass.optString("subject", "").trim()
          val room = nextClass.optString("room", "").trim()
          val startTime = nextClass.optString("startTime", "").trim()
          val endTime = nextClass.optString("endTime", "").trim()

          result["nextLabel"] = "$period $subject ($room)"
          result["nextTime"] = "$startTime ~ $endTime"

          val startCal = Calendar.getInstance()
          val startM = parseMinutes(startTime)
          startCal.set(Calendar.HOUR_OF_DAY, startM / 60)
          startCal.set(Calendar.MINUTE, startM % 60)
          startCal.set(Calendar.SECOND, 0)
          result["nextCountdown"] = formatCountdown(((startCal.timeInMillis - cal.timeInMillis) / 1000).toInt())
      } else {
          result["nextLabel"] = "下節課：無"
          result["nextTime"] = "--:-- ~ --:--"
          result["nextCountdown"] = "00:00:00"
      }

      return result
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
