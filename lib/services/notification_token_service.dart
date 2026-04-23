import 'dart:async';
import 'dart:convert';

import 'package:android_id/android_id.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';
import 'cache_service.dart';
import 'vocpass_auth_service.dart';

class NotificationTokenService {
  NotificationTokenService._();
  static final NotificationTokenService instance = NotificationTokenService._();

  final AndroidId _androidId = const AndroidId();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  Timer? _startupRetryTimer;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _requestPermissionIfPossible();

    await uploadNow();
    _scheduleStartupRetry();

    final messaging = await _getMessagingIfReady();
    if (messaging != null) {
      _tokenRefreshSub = messaging.onTokenRefresh.listen(
        (token) {
          unawaited(_uploadToken(fcmTokenOverride: token, reason: 'token_refresh'));
        },
        onError: (Object e) {
          if (kDebugMode) {
            print('[NotifyToken] onTokenRefresh error: $e');
          }
        },
      );
    }
  }

  Future<void> uploadNow() {
    return _uploadToken(reason: 'app_open_or_manual');
  }

  Future<void> syncDynamicNotifyConfig({
    required bool isOpen,
    List<Map<String, dynamic>>? curriculum,
    String reason = 'dynamic_notify_sync',
  }) {
    return _uploadToken(
      reason: reason,
      isOpenOverride: isOpen,
      curriculumOverride: curriculum,
    );
  }

  Future<void> syncDynamicNotifyConfigFromCache({
    String reason = 'dynamic_notify_sync_from_cache',
    bool? isOpenOverride,
  }) {
    return _uploadToken(
      reason: reason,
      isOpenOverride: isOpenOverride,
      curriculumOverride: buildCurriculumJsonFromCache(),
    );
  }

  List<Map<String, dynamic>> buildCurriculumJsonFromCache() {
    final cache = CacheService.instance;
    final cachedTimetable = cache.getCachedTimetable();
    final curriculum = cachedTimetable?.curriculum ?? const <String, CourseInfo>{};
    final apiPeriodTimes = cachedTimetable?.periodTimes ?? const <String, PeriodTime>{};
    final manualCurriculum = cache.manualCurriculum;
    final manualRoomTeacher = cache.manualRoomTeacher;
    final manualPeriodTimes = cache.manualPeriodTimes;

    final slots = <String, Map<String, String>>{};

    for (final entry in curriculum.entries) {
      for (final schedule in entry.value.schedule) {
        final key = '${schedule.weekday}|${schedule.period}';
        slots[key] = {
          'weekday': schedule.weekday,
          'period': schedule.period,
          'subject': entry.key,
          'room': '',
          'teacher': '',
        };
      }
    }

    for (final entry in manualCurriculum.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) continue;
      slots[entry.key] = {
        'weekday': parts[0],
        'period': parts[1],
        'subject': entry.value,
        'room': manualRoomTeacher[entry.key]?.room ?? '',
        'teacher': manualRoomTeacher[entry.key]?.teacher ?? '',
      };
    }

    final result = <Map<String, dynamic>>[];
    for (final slot in slots.values) {
      final subject = (slot['subject'] ?? '').trim();
      if (subject.isEmpty) continue;

      final period = slot['period'] ?? '';
      final periodTime = manualPeriodTimes[period] ?? apiPeriodTimes[period];

      result.add({
        'weekday': slot['weekday'] ?? '',
        'period': period,
        'subject': subject,
        'startTime': periodTime?.startTime ?? '',
        'endTime': periodTime?.endTime ?? '',
        'room': slot['room'] ?? '',
        'teacher': slot['teacher'] ?? '',
      });
    }

    result.sort((a, b) {
      final weekdayCompare = _weekdayOrder(a['weekday'].toString())
          .compareTo(_weekdayOrder(b['weekday'].toString()));
      if (weekdayCompare != 0) return weekdayCompare;
      return _periodOrder(a['period'].toString())
          .compareTo(_periodOrder(b['period'].toString()));
    });

    return result;
  }

  Future<FirebaseMessaging?> _getMessagingIfReady() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return FirebaseMessaging.instance;
    } catch (e) {
      if (kDebugMode) {
        print('[NotifyToken] Firebase init unavailable: $e');
      }
      return null;
    }
  }

  Future<void> _requestPermissionIfPossible() async {
    try {
      final messaging = await _getMessagingIfReady();
      if (messaging == null) return;
      final settings = await messaging.requestPermission();
      if (kDebugMode) {
        print(
          '[NotifyToken] permission status=${settings.authorizationStatus.name} '
          'alert=${settings.alert} badge=${settings.badge} sound=${settings.sound}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotifyToken] requestPermission failed: $e');
      }
    }
  }

  void _scheduleStartupRetry() {
    _startupRetryTimer?.cancel();
    _startupRetryTimer = Timer(const Duration(seconds: 8), () {
      unawaited(_uploadToken(reason: 'startup_retry'));
    });
  }

  Future<void> _uploadToken({
    String? fcmTokenOverride,
    required String reason,
    bool? isOpenOverride,
    List<Map<String, dynamic>>? curriculumOverride,
  }) async {
    try {
      final deviceToken = await _androidId.getId();
      if (deviceToken == null || deviceToken.isEmpty) {
        if (kDebugMode) {
          print('[NotifyToken] skip upload ($reason): SSAID unavailable');
        }
        return;
      }

      String? fcmToken = fcmTokenOverride;
      if (fcmToken == null) {
        try {
          final messaging = await _getMessagingIfReady();
          if (messaging == null && kDebugMode) {
            print('[NotifyToken] getToken skipped ($reason): Firebase unavailable');
          }
          fcmToken = await messaging?.getToken();
        } catch (e) {
          if (kDebugMode) {
            print('[NotifyToken] getToken failed ($reason): $e');
            print('[NotifyToken] getToken diagnosis: ${_diagnoseTokenError(e)}');
          }
        }
      }

      if (kDebugMode && (fcmToken == null || fcmToken.isEmpty)) {
        print('[NotifyToken] fcm token is empty ($reason), fallback upload with SSAID only');
      }

      final isOpen = isOpenOverride ?? CacheService.instance.autoStartDynamicIsland;
      final curriculum = curriculumOverride ?? buildCurriculumJsonFromCache();

      final payload = <String, dynamic>{
        'device_token': deviceToken,
        'fcm_token': fcmToken ?? '',
        'is_open': isOpen,
        'curriculum': curriculum,
        'valid': true,
      };

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Logged-in users include Authorization; guests upload without it.
      VocPassAuthService.instance.applyAuthHeader(headers);
      if (kDebugMode) {
        print('[NotifyToken] upload context ($reason): hasAuthorization=${VocPassAuthService.instance.hasToken}');
      }

      final uri = Uri.parse('${AppConfig.vocPassApiHost}/api/user/notify/android');
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('[NotifyToken] upload ($reason) status=${response.statusCode} body=${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotifyToken] upload failed ($reason): $e');
      }
    }
  }

  Future<void> dispose() async {
    _startupRetryTimer?.cancel();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }

  String _diagnoseTokenError(Object error) {
    final text = error.toString().toUpperCase();
    if (text.contains('FIS_AUTH_ERROR') || text.contains('AUTHENTICATION_FAILED')) {
      return 'Firebase Installations 驗證失敗。常見原因: 模擬器 Play 服務狀態異常、Google 帳號未登入、網路或時間不同步、API key 限制不匹配。';
    }
    if (text.contains('SERVICE_UNAVAILABLE')) {
      return 'Firebase 服務暫時不可用，可稍後重試。';
    }
    if (text.contains('MISSING_INSTANCEID_SERVICE')) {
      return '裝置缺少 Google Play Services，FCM 無法工作。';
    }
    return '未知錯誤，請先確認 google-services.json、Play Services、網路與時間設定。';
  }

  int _weekdayOrder(String weekday) {
    const order = {
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
      '1': 1,
      '2': 2,
      '3': 3,
      '4': 4,
      '5': 5,
      '6': 6,
      '7': 7,
    };
    return order[weekday] ?? 99;
  }

  int _periodOrder(String period) {
    const order = {
      '早讀': 0,
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '十一': 11,
      '十二': 12,
      '十三': 13,
      '十四': 14,
      '十五': 15,
      '十六': 16,
      '十七': 17,
      '十八': 18,
      '十九': 19,
      '二十': 20,
    };
    final mapped = order[period];
    if (mapped != null) return mapped;
    return int.tryParse(period) ?? 999;
  }
}
