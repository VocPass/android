import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'cache_service.dart';

class WidgetService {
  static const String appGroupId = 'group.vocpass.app';
  static const String androidWidgetName = 'ScheduleWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  static Future<void> updateScheduleWidget() async {
    final cachedTimetable = CacheService.instance.getCachedTimetable();
    if (cachedTimetable == null || cachedTimetable.curriculum.isEmpty) {
      await _saveWidgetData('目前無課表', '請開啟App重新載入');
      return;
    }

    final manualCurriculum = CacheService.instance.manualCurriculum;
    final manualRoomTeacher = CacheService.instance.manualRoomTeacher;
    final periodsPerDay = CacheService.instance.periodsPerDay; // 預設 7

    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    
    // 找出有課那一天
    int targetWeekday = currentWeekday;
    bool foundToday = _hasClasses(cachedTimetable, manualCurriculum, targetWeekday);
    
    if (!foundToday) {
      // 找下一天有課的
      targetWeekday = _findNextClassDay(cachedTimetable, manualCurriculum, currentWeekday);
    }

    if (targetWeekday == 0) {
      await _saveWidgetData('無課表', '沒有找到近期的課');
      return;
    }

    String dayName = _getWeekdayName(targetWeekday);
    String title = (targetWeekday == currentWeekday) ? '今日課表 (週$dayName)' : '下週$dayName 課表';

    StringBuffer scheduleText = StringBuffer();
    
    // 只顯示前 N 節
    for (int i = 1; i <= periodsPerDay; i++) {
        String period = i.toString();
        // 對應早節和第1~7節
        if (i <= 7) {
            const numMap = ['一', '二', '三', '四', '五', '六', '七'];
            period = numMap[i - 1];
        }
        
        String subject = _getSubject(cachedTimetable, manualCurriculum, targetWeekday.toString(), period);
        String room = _getRoom(cachedTimetable, manualRoomTeacher, targetWeekday.toString(), period);

        if (subject.isNotEmpty) {
            String roomText = room.isNotEmpty ? ' ($room)' : '';
            scheduleText.writeln('第$period節：$subject$roomText');
        } else {
            scheduleText.writeln('第$period節：-');
        }
    }

    await _saveWidgetData(title, scheduleText.toString());
  }

  static bool _hasClasses(TimetableData data, Map<String, String> manual, int weekday) {
      String weekdayStr = weekday.toString();
      for (final entry in data.entries) {
          if (entry.weekday == weekdayStr) return true;
      }
      for (final key in manual.keys) {
          if (key.startsWith('$weekdayStr|')) return true;
      }
      return false;
  }

  static int _findNextClassDay(TimetableData data, Map<String, String> manual, int currentWeekday) {
      for (int i = 1; i <= 7; i++) {
          int checkDay = currentWeekday + i;
          if (checkDay > 7) checkDay -= 7;
          if (_hasClasses(data, manual, checkDay)) return checkDay;
      }
      return 0;
  }

  static String _getSubject(TimetableData data, Map<String, String> manual, String weekday, String period) {
      final key = '$weekday|$period';
      if (manual.containsKey(key)) return manual[key]!;
      for (final entry in data.curriculum.entries) {
          for (final s in entry.value.schedule) {
              if (s.weekday == weekday && s.period == period) return entry.key;
          }
      }
      return '';
  }

  static String _getRoom(TimetableData data, Map<String, CourseExtra> manualRt, String weekday, String period) {
      final key = '$weekday|$period';
      if (manualRt.containsKey(key)) return manualRt[key]!.room;
      for (final entry in data.curriculum.entries) {
          for (final s in entry.value.schedule) {
              if (s.weekday == weekday && s.period == period) {
                  return ''; // api Extra not parsed deep in TimetableData entry without info map directly easily here, fallback mapping
              }
          }
      }
      return '';
  }

  static String _getWeekdayName(int weekday) {
      const names = ['一', '二', '三', '四', '五', '六', '日'];
      if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
      return '';
  }

  static Future<void> _saveWidgetData(String title, String scheduleText) async {
    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_schedule_text', scheduleText);
    await HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: androidWidgetName, // 之後若有 iOS widget 也可用同名
    );
  }
}
