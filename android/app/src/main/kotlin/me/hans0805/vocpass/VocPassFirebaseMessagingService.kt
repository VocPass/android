package me.hans0805.vocpass

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

class VocPassFirebaseMessagingService : FirebaseMessagingService() {

  companion object {
    private const val TAG = "VocPassFCM"
  }

  override fun onNewToken(token: String) {
    super.onNewToken(token)
    Log.d(TAG, "onNewToken: $token")
  }

  override fun onMessageReceived(message: RemoteMessage) {
    val data = message.data
    Log.d(TAG, "onMessageReceived from=${message.from} dataKeys=${data.keys}")
    if (data.isEmpty()) {
      Log.w(TAG, "data is empty, ignoring")
      return
    }

    val curriculumStr = data["curriculum"]
    if (curriculumStr == null) {
      Log.w(TAG, "no 'curriculum' key in data, ignoring")
      return
    }
    try {
        val classStatus = parseCurriculumToClassStatus(curriculumStr)
        Log.d(TAG, "parsed status=$classStatus")

        val currentRemain = classStatus["currentRemainingSec"]?.toLongOrNull() ?: -1
        val nextRemain = classStatus["nextRemainingSec"]?.toLongOrNull() ?: -1

        // 今日課程已結束（無 current 也無 next）→ 取消常駐通知，讓它自動消失。
        if (currentRemain < 0 && nextRemain < 0) {
            Log.d(TAG, "no current/next class today, cancelling notification")
            ClassStatusNotifier.cancel(this)
            return
        }

        ClassStatusNotifier.show(
            this,
            ClassStatusNotifier.ClassStatus(
                currentLabel = classStatus["currentLabel"] ?: "目前無上課",
                currentTime = classStatus["currentTime"] ?: "--:-- ~ --:--",
                currentCountdown = classStatus["currentCountdown"] ?: "00:00:00",
                nextLabel = classStatus["nextLabel"] ?: "下節課：無",
                nextTime = classStatus["nextTime"] ?: "--:-- ~ --:--",
                nextCountdown = classStatus["nextCountdown"] ?: "00:00:00",
                currentRemainingSec = currentRemain,
                nextRemainingSec = nextRemain,
            ),
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

      // 先算下節課，好讓「下課中」時主倒數能引用下一節開始的剩餘秒數。
      var nextStartRemainSec = -1L
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
          nextStartRemainSec = ((startCal.timeInMillis - cal.timeInMillis) / 1000).coerceAtLeast(0)
          result["nextCountdown"] = formatCountdown(nextStartRemainSec.toInt())
          result["nextRemainingSec"] = nextStartRemainSec.toString()
      } else {
          result["nextLabel"] = "下節課：無"
          result["nextTime"] = "--:-- ~ --:--"
          result["nextCountdown"] = "00:00:00"
          result["nextRemainingSec"] = "-1"
      }

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
          val currentRemainSec = ((endCal.timeInMillis - cal.timeInMillis) / 1000).coerceAtLeast(0)
          result["currentCountdown"] = formatCountdown(currentRemainSec.toInt())
          result["currentRemainingSec"] = currentRemainSec.toString()
      } else if (nextClass != null) {
          // 下課中：這節課區塊只顯示「下課中」，時間與倒數留給下方「下節課」呈現。
          result["currentLabel"] = "下課中"
          result["currentTime"] = ""
          result["currentCountdown"] = "00:00:00"
          result["currentRemainingSec"] = "-1"
      } else {
          // 當天已無 current 也無 next：今日課程已結束。
          result["currentLabel"] = "今日課程已結束"
          result["currentTime"] = "--:-- ~ --:--"
          result["currentCountdown"] = "00:00:00"
          result["currentRemainingSec"] = "-1"
      }

      return result
  }
}
