import 'package:home_widget/home_widget.dart';

import '../models/models.dart';
import 'cache_service.dart';

class WidgetService {
  static const String appGroupId = 'group.vocpass.app';
  static const String androidWidgetName = 'ScheduleWidgetProvider';

  // DateTime.weekday: 1=Mon ... 7=Sun → 中文（與 API 格式一致）
  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
  // 節次：索引 0 → "一" ... 索引 6 → "七"
  static const _periodNames = ['一', '二', '三', '四', '五', '六', '七'];

  static String _weekdayCn(int weekday) =>
      (weekday >= 1 && weekday <= 7) ? _weekdayNames[weekday - 1] : '';

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
    final periodsPerDay = CacheService.instance.periodsPerDay;

    final now = DateTime.now();
    final currentWeekday = now.weekday; // 1=Mon, 7=Sun

    // 找出有課那一天
    int targetWeekday = currentWeekday;
    if (!_hasClasses(cachedTimetable, manualCurriculum, targetWeekday)) {
      targetWeekday = _findNextClassDay(cachedTimetable, manualCurriculum, currentWeekday);
    }

    if (targetWeekday == 0) {
      await _saveWidgetData('無課表', '沒有找到近期的課');
      return;
    }

    final dayNameCn = _weekdayCn(targetWeekday);
    String title;
    if (targetWeekday == currentWeekday) {
      title = '今日課表 (週$dayNameCn)';
    } else {
      final diff = (targetWeekday - currentWeekday + 7) % 7;
      title = diff == 1 ? '明日課表 (週$dayNameCn)' : '週$dayNameCn 課表';
    }

    // API 的 weekday 為中文
    final weekdayCn = _weekdayCn(targetWeekday);
    final scheduleText = StringBuffer();

    for (int i = 1; i <= periodsPerDay; i++) {
      // API 的 period 也是中文
      final periodCn = i <= 7 ? _periodNames[i - 1] : i.toString();

      final subject = _getSubject(cachedTimetable, manualCurriculum, weekdayCn, periodCn);
      final room = _getRoom(manualRoomTeacher, weekdayCn, periodCn);

      if (subject.isNotEmpty) {
        final roomText = room.isNotEmpty ? ' ($room)' : '';
        scheduleText.writeln('第$periodCn節：$subject$roomText');
      } else {
        scheduleText.writeln('第$periodCn節：-');
      }
    }

    await _saveWidgetData(title, scheduleText.toString());
  }

  /// 判斷某天有沒有課。API weekday 與 period 皆為中文，須先轉換 DateTime.weekday
  static bool _hasClasses(
    TimetableData data,
    Map<String, String> manual,
    int weekday,
  ) {
    final cn = _weekdayCn(weekday);
    for (final entry in data.curriculum.entries) {
      for (final s in entry.value.schedule) {
        if (s.weekday == cn) return true;
      }
    }
    for (final key in manual.keys) {
      if (key.startsWith('$cn|')) return true;
    }
    return false;
  }

  static int _findNextClassDay(
    TimetableData data,
    Map<String, String> manual,
    int currentWeekday,
  ) {
    for (int i = 1; i <= 7; i++) {
      final checkDay = (currentWeekday - 1 + i) % 7 + 1;
      if (_hasClasses(data, manual, checkDay)) return checkDay;
    }
    return 0;
  }

  /// [weekday] 與 [period] 皆為中文，直接與 API CourseSchedule 比對
  static String _getSubject(
    TimetableData data,
    Map<String, String> manual,
    String weekday,
    String period,
  ) {
    final key = '$weekday|$period';
    if (manual.containsKey(key)) return manual[key]!;

    for (final entry in data.curriculum.entries) {
      for (final s in entry.value.schedule) {
        if (s.weekday == weekday && s.period == period) return entry.key;
      }
    }
    return '';
  }

  static String _getRoom(
    Map<String, CourseExtra> manualRt,
    String weekday,
    String period,
  ) {
    return manualRt['$weekday|$period']?.room ?? '';
  }

  static Future<void> _saveWidgetData(String title, String scheduleText) async {
    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_schedule_text', scheduleText);
    await HomeWidget.updateWidget(
      name: androidWidgetName,
      iOSName: androidWidgetName,
    );
  }
}
