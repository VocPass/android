// 「出來玩」When2meet 功能資料模型

class W2MEventListResponse {
  final List<W2MEventSummary> created;
  final List<W2MEventSummary> participated;

  W2MEventListResponse({required this.created, required this.participated});

  factory W2MEventListResponse.fromJson(Map<String, dynamic> json) =>
      W2MEventListResponse(
        created: (json['created'] as List? ?? [])
            .map((e) => W2MEventSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        participated: (json['participated'] as List? ?? [])
            .map((e) => W2MEventSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class W2MEventSummary {
  final String id;
  final String title;
  final String description;
  final List<String> dates;
  final W2MUserInfo creator;

  W2MEventSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.dates,
    required this.creator,
  });

  factory W2MEventSummary.fromJson(Map<String, dynamic> json) =>
      W2MEventSummary(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dates: List<String>.from(json['dates'] as List? ?? []),
        creator: W2MUserInfo.fromJson(json['creator'] as Map<String, dynamic>),
      );
}

class W2MUserInfo {
  final String id;
  final String name;
  final String? avatar;

  W2MUserInfo({required this.id, required this.name, this.avatar});

  factory W2MUserInfo.fromJson(Map<String, dynamic> json) => W2MUserInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatar: json['avatar'] as String?,
      );

  String get displayName => name.isEmpty ? id : name;
  String? get avatarURL =>
      (avatar != null && avatar!.isNotEmpty) ? avatar : null;
}

class W2MEvent {
  final String id;
  final String title;
  final List<String> slots;
  final List<W2MUserAvailability> availability;
  final W2MUserInfo? creator;

  W2MEvent({
    required this.id,
    required this.title,
    required this.slots,
    required this.availability,
    this.creator,
  });

  factory W2MEvent.fromJson(Map<String, dynamic> json) => W2MEvent(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        slots: List<String>.from(json['slots'] as List? ?? []),
        availability: (json['availability'] as List? ?? [])
            .map((e) =>
                W2MUserAvailability.fromJson(e as Map<String, dynamic>))
            .toList(),
        creator: json['creator'] != null
            ? W2MUserInfo.fromJson(json['creator'] as Map<String, dynamic>)
            : null,
      );

  List<String> get dates {
    final seen = <String>{};
    final result = <String>[];
    for (final s in slots) {
      final parts = s.split(' ');
      if (parts.isNotEmpty && seen.add(parts[0])) result.add(parts[0]);
    }
    return result;
  }

  int slotCount(String slotLabel) =>
      availability.where((a) => a.slots.contains(slotLabel)).length;

  List<W2MUserAvailability> usersAvailable(String slotLabel) =>
      availability.where((a) => a.slots.contains(slotLabel)).toList();

  int get maxCount {
    int m = 0;
    for (final s in slots) {
      final c = slotCount(s);
      if (c > m) m = c;
    }
    return m == 0 ? 1 : m;
  }
}

class W2MUserAvailability {
  final W2MUserInfo user;
  final List<String> slots;

  W2MUserAvailability({required this.user, required this.slots});

  factory W2MUserAvailability.fromJson(Map<String, dynamic> json) =>
      W2MUserAvailability(
        user: W2MUserInfo.fromJson(json['user'] as Map<String, dynamic>),
        slots: List<String>.from(json['slots'] as List? ?? []),
      );
}

/// 本地時間格子模型
class W2MSlot {
  final String dateString;
  final String timeString;

  const W2MSlot({required this.dateString, required this.timeString});

  String get label => '$dateString $timeString';

  @override
  bool operator ==(Object other) =>
      other is W2MSlot && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// 產生顯示用時間列表：06:00 ~ 23:30 每 30 分鐘一格
List<String> w2mDisplayTimes() {
  final result = <String>[];
  for (int h = 6; h < 24; h++) {
    for (final m in [0, 30]) {
      result.add(
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    }
  }
  return result;
}

/// 日期短顯示，e.g. "4/10\n(四)"
String w2mShortDate(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    final w = weekdays[date.weekday % 7];
    return '${date.month}/${date.day}\n($w)';
  } catch (_) {
    return dateStr;
  }
}
