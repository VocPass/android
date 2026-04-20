import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CacheService extends ChangeNotifier {
  static final CacheService instance = CacheService._internal();
  CacheService._internal();

  static const _cacheExpirationSeconds = 24 * 60 * 60;
  static const _timetableParserVersion = 'v3';
  static const _timetableParserVersionKey = 'timetable_parser_version';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    invalidateTimetableCacheIfNeeded();
  }

  SharedPreferences get prefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('CacheService not initialized');
    }
    return prefs;
  }

  bool get hasSeenOnboarding => prefs.getBool('has_seen_onboarding') ?? false;

  set hasSeenOnboarding(bool value) {
    prefs.setBool('has_seen_onboarding', value);
    notifyListeners();
  }

  bool get rememberCredentials => prefs.getBool('remember_credentials') ?? false;

  set rememberCredentials(bool value) {
    prefs.setBool('remember_credentials', value);
    notifyListeners();
  }

  String? get savedUsername => prefs.getString('saved_username');

  set savedUsername(String? value) {
    if (value == null) {
      prefs.remove('saved_username');
    } else {
      prefs.setString('saved_username', value);
    }
    notifyListeners();
  }

  String? get savedPassword => prefs.getString('saved_password');

  set savedPassword(String? value) {
    if (value == null) {
      prefs.remove('saved_password');
    } else {
      prefs.setString('saved_password', value);
    }
    notifyListeners();
  }

  String? get savedSchoolCode => prefs.getString('saved_school_code');

  set savedSchoolCode(String? value) {
    if (value == null) {
      prefs.remove('saved_school_code');
    } else {
      prefs.setString('saved_school_code', value);
    }
    notifyListeners();
  }

  bool get autoStartDynamicIsland =>
      prefs.getBool('auto_start_dynamic_island') ?? false;

  set autoStartDynamicIsland(bool value) {
    prefs.setBool('auto_start_dynamic_island', value);
    notifyListeners();
  }

  int get autoStartMinutesBefore {
    final v = prefs.getInt('auto_start_minutes_before') ?? 0;
    return v == 0 ? 30 : v;
  }

  set autoStartMinutesBefore(int value) {
    prefs.setInt('auto_start_minutes_before', value);
    notifyListeners();
  }

  String get savedClassName => prefs.getString('saved_class_name') ?? '';

  set savedClassName(String value) {
    prefs.setString('saved_class_name', value);
    notifyListeners();
  }

  void saveLoginCredentials({
    required String username,
    required String password,
    String? schoolCode,
  }) {
    savedUsername = username;
    savedPassword = password;
    savedSchoolCode = schoolCode;
    rememberCredentials = true;
  }

  void clearLoginCredentials() {
    savedUsername = null;
    savedPassword = null;
    savedSchoolCode = null;
    rememberCredentials = false;
  }

  void invalidateTimetableCacheIfNeeded() {
    final stored = prefs.getString(_timetableParserVersionKey) ?? '';
    if (stored != _timetableParserVersion) {
      clearTimetableCache();
      prefs.setString(_timetableParserVersionKey, _timetableParserVersion);
    }
  }

  TimetableData? getCachedTimetable() {
    if (_isCacheExpired('cached_timetable_timestamp')) {
      clearTimetableCache();
      return null;
    }
    final raw = prefs.getString('cached_timetable');
    if (raw == null || raw.isEmpty) return null;
    return TimetableData.fromJsonString(raw);
  }

  void cacheTimetable(TimetableData timetable) {
    prefs.setString('cached_timetable', timetable.toJsonString());
    _setTimestamp('cached_timetable_timestamp');
  }

  void clearTimetableCache() {
    prefs.remove('cached_timetable');
    prefs.remove('cached_timetable_timestamp');
  }

  Map<String, CourseInfo>? getCachedCurriculum() {
    if (_isCacheExpired('cached_curriculum_timestamp')) {
      clearCurriculumCache();
      return null;
    }
    final raw = prefs.getString('cached_curriculum');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(
            key,
            CourseInfo.fromJson((value as Map).cast<String, dynamic>()),
          ));
    } catch (_) {
      clearCurriculumCache();
      return null;
    }
  }

  void cacheCurriculum(Map<String, CourseInfo> curriculum) {
    final encoded = jsonEncode(curriculum.map((key, value) => MapEntry(key, {
          'count': value.count,
          'schedule': value.schedule
              .map((e) => {'weekday': e.weekday, 'period': e.period})
              .toList(),
        })));
    prefs.setString('cached_curriculum', encoded);
    _setTimestamp('cached_curriculum_timestamp');
  }

  void clearCurriculumCache() {
    prefs.remove('cached_curriculum');
    prefs.remove('cached_curriculum_timestamp');
  }

  List<ExamMenuItem>? getCachedExamMenu() {
    if (_isCacheExpired('cached_exam_menu_timestamp')) {
      clearExamMenuCache();
      return null;
    }
    final raw = prefs.getString('cached_exam_menu');
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => ExamMenuItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      clearExamMenuCache();
      return null;
    }
  }

  void cacheExamMenu(List<ExamMenuItem> items) {
    final encoded = jsonEncode(items
        .map((e) => {
              'name': e.name,
              'url': e.url,
              'fullUrl': e.fullUrl,
            })
        .toList());
    prefs.setString('cached_exam_menu', encoded);
    _setTimestamp('cached_exam_menu_timestamp');
  }

  void clearExamMenuCache() {
    prefs.remove('cached_exam_menu');
    prefs.remove('cached_exam_menu_timestamp');
  }

  bool get isCurriculumSharing =>
      prefs.getBool('is_curriculum_sharing') ?? false;

  set isCurriculumSharing(bool value) {
    prefs.setBool('is_curriculum_sharing', value);
    notifyListeners();
  }

  List<String> get followedUsernames {
    return prefs.getStringList('followed_usernames') ?? [];
  }

  set followedUsernames(List<String> value) {
    prefs.setStringList('followed_usernames', value);
    notifyListeners();
  }

  // 每天節數
  int get periodsPerDay => prefs.getInt('periods_per_day') ?? 7;

  set periodsPerDay(int value) {
    prefs.setInt('periods_per_day', value);
    notifyListeners();
  }

  // 每學期週數
  int get weeksPerSemester => prefs.getInt('weeks_per_semester') ?? 18;

  set weeksPerSemester(int value) {
    prefs.setInt('weeks_per_semester', value);
    notifyListeners();
  }

  // 手動課表覆寫 (key = "weekday|period", value = subject)
  Map<String, String> get manualCurriculum {
    final raw = prefs.getString('manual_curriculum');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  set manualCurriculum(Map<String, String> value) {
    prefs.setString('manual_curriculum', jsonEncode(value));
    notifyListeners();
  }

  // 手動教室/教師覆寫
  Map<String, CourseExtra> get manualRoomTeacher {
    final raw = prefs.getString('manual_room_teacher');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
            k,
            CourseExtra.fromJson((v as Map).cast<String, dynamic>()),
          ));
    } catch (_) {
      return {};
    }
  }

  set manualRoomTeacher(Map<String, CourseExtra> value) {
    prefs.setString(
        'manual_room_teacher',
        jsonEncode(
            value.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }

  // 手動節次時間覆寫
  Map<String, PeriodTime> get manualPeriodTimes {
    final raw = prefs.getString('manual_period_times');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
            k,
            PeriodTime.fromMap((v as Map).cast<String, dynamic>()),
          ));
    } catch (_) {
      return {};
    }
  }

  set manualPeriodTimes(Map<String, PeriodTime> value) {
    prefs.setString(
        'manual_period_times',
        jsonEncode(
            value.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }

  void saveCookies(List<Map<String, String>> cookies) {
    prefs.setString('saved_cookies', jsonEncode(cookies));
  }

  List<Map<String, String>> loadCookies() {
    final raw = prefs.getString('saved_cookies');
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => {'name': e['name'].toString(), 'value': e['value'].toString()})
          .toList();
    } catch (_) {
      return [];
    }
  }

  void clearCookies() {
    prefs.remove('saved_cookies');
  }

  void clearAllCache() {
    clearCurriculumCache();
    clearTimetableCache();
    clearExamMenuCache();
  }

  bool _isCacheExpired(String timestampKey) {
    final timestamp = prefs.getInt(timestampKey);
    if (timestamp == null) return true;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > _cacheExpirationSeconds * 1000;
  }

  void _setTimestamp(String key) {
    prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }
}
