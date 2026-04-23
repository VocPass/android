package me.hans0805.vocpass

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_schedule).apply {
                val title = widgetData.getString("widget_title", "近期課表")
                val schedule = widgetData.getString("widget_schedule_text", "目前無資料\n請開啟App更新")
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_schedule_text, schedule)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
