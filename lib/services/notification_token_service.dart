import 'dart:async';
import 'dart:convert';

import 'package:android_id/android_id.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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
      await messaging.requestPermission();
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

  Future<void> _uploadToken({String? fcmTokenOverride, required String reason}) async {
    try {
      final deviceToken = await _androidId.getId();
      if (deviceToken == null || deviceToken.isEmpty) {
        if (kDebugMode) {
          print('[NotifyToken] skip upload ($reason): SSAID unavailable');
        }
        return;
      }

      final messaging = await _getMessagingIfReady();
      final fcmToken = fcmTokenOverride ?? await messaging?.getToken();

      final payload = <String, dynamic>{
        'device_token': deviceToken,
        'fcm_token': fcmToken,
        'is_open': true,
        'valid': true,
      };

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Logged-in users include Authorization; guests upload without it.
      VocPassAuthService.instance.applyAuthHeader(headers);

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
}
