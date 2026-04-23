import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'notification_token_service.dart';

class DynamicIslandService {
  DynamicIslandService._internal();

  static final DynamicIslandService instance = DynamicIslandService._internal();

  static const MethodChannel _channel = MethodChannel('vocpass/dynamic_island');

  Timer? _timer;
  List<_ClassItem> _classes = const [];

  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> startClassStatusSync() async {
    if (!Platform.isAndroid) return;

    _classes = _loadClassItemsFromCurriculum();
    _timer?.cancel();

    if (_classes.isEmpty) {
      await cancelClassStatusNotification();
      return;
    }

    await _updateClassStatusNotification();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateClassStatusNotification();
    });
  }

  Future<void> stopClassStatusSync() async {
    _timer?.cancel();
    _timer = null;
    await cancelClassStatusNotification();
  }

  Future<void> cancelClassStatusNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelClassStatusNotification');
    } on PlatformException {
      // Ignore cancel errors.
    }
  }

  Future<void> showOngoingPlaceholderNotification() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('showOngoingPlaceholderNotification');
    } on PlatformException {
      // Ignore runtime errors to keep app stable.
    }
  }

  Future<void> _updateClassStatusNotification() async {
    _classes = _loadClassItemsFromCurriculum();
    if (_classes.isEmpty) {
      await cancelClassStatusNotification();
      return;
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final nowSeconds = now.second;

    _ClassItem? current;
    _ClassItem? next;

    for (final item in _classes) {
      final startsBeforeNow = item.startMinutes < nowMinutes ||
          (item.startMinutes == nowMinutes && nowSeconds >= 0);
      final endsAfterNow = item.endMinutes > nowMinutes ||
          (item.endMinutes == nowMinutes && nowSeconds == 0);

      if (startsBeforeNow && endsAfterNow) {
        current = item;
        continue;
      }

      if (item.startMinutes > nowMinutes ||
          (item.startMinutes == nowMinutes && nowSeconds == 0)) {
        next = item;
        break;
      }
    }

    if (current == null && next == null) {
      await cancelClassStatusNotification();
      return;
    }

    final currentLabel = current != null
        ? '${current.period} ${current.subject} (${current.room})'
        : '目前無上課';
    final currentTime = current?.timeRange ?? '--:-- ~ --:--';
    final currentCountdown = current != null
        ? _formatDuration(_secondsUntil(now, current.endMinutes))
        : '--:--:--';

    final nextLabel = next != null
        ? '${next.period} ${next.subject} (${next.room})'
        : '下節課：無';
    final nextTime = next?.timeRange ?? '--:-- ~ --:--';
    final nextCountdown = next != null
        ? _formatDuration(_secondsUntil(now, next.startMinutes))
        : '--:--:--';

    try {
      await _channel.invokeMethod<void>('showClassStatusNotification', {
        'currentLabel': currentLabel,
        'currentTime': currentTime,
        'currentCountdown': currentCountdown,
        'nextLabel': nextLabel,
        'nextTime': nextTime,
        'nextCountdown': nextCountdown,
      });
    } on PlatformException {
      // Ignore runtime errors to keep app stable.
    }
  }

  int _secondsUntil(DateTime now, int targetMinutes) {
    final target = DateTime(now.year, now.month, now.day)
        .add(Duration(minutes: targetMinutes));
    final diff = target.difference(now).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<_ClassItem> _loadClassItemsFromCurriculum() {
    final items = NotificationTokenService.instance.buildDynamicClassListFromCache();
    final todayWeekday = _weekdayToZh(DateTime.now().weekday);

    final result = items
        .where((e) {
          final weekday = (e['weekday'] ?? '').toString();
          // If weekday is provided, only keep today's classes.
          if (weekday.isNotEmpty) return weekday == todayWeekday;
          return true;
        })
        .map((e) => _ClassItem.fromJson(e))
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return result;
  }

  String _weekdayToZh(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '一';
      case DateTime.tuesday:
        return '二';
      case DateTime.wednesday:
        return '三';
      case DateTime.thursday:
        return '四';
      case DateTime.friday:
        return '五';
      case DateTime.saturday:
        return '六';
      case DateTime.sunday:
        return '日';
      default:
        return '';
    }
  }
}

class _ClassItem {
  final String period;
  final String subject;
  final String startTime;
  final String endTime;
  final String room;

  const _ClassItem({
    required this.period,
    required this.subject,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  factory _ClassItem.fromJson(Map<String, dynamic> json) {
    return _ClassItem(
      period: (json['period'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
      room: (json['room'] ?? '').toString(),
    );
  }

  int get startMinutes => _parseMinutes(startTime);

  int get endMinutes => _parseMinutes(endTime);

  String get timeRange => '$startTime ~ $endTime';

  int _parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}
