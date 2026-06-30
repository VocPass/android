// 論壇共用 UI 元件

import 'package:flutter/material.dart';

import '../../models/forum_models.dart';

/// 將 ISO8601 等格式的時間字串轉成中文相對時間（例：3 小時前）。
String forumRelativeTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.isNegative) return '剛剛';
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30} 個月前';
  return '${diff.inDays ~/ 365} 年前';
}

/// 將 #RRGGBB / RRGGBB 轉成 Color，失敗回傳 null。
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// 作者徽章類型，與 iOS 的 ForumAuthorBadge 對應。
enum ForumBadge {
  schoolModerator,
  vocPassAdmin;

  Color get color =>
      this == ForumBadge.vocPassAdmin ? Colors.amber : Colors.blue;
  String get label =>
      this == ForumBadge.vocPassAdmin ? 'VocPass 管理員' : '學校版主';
  IconData get icon => this == ForumBadge.vocPassAdmin
      ? Icons.verified
      : Icons.shield;
}

/// 依使用者 ID 計算其在指定學校 / VocPass 的徽章。
ForumBadge? badgeForUser({
  required String? userID,
  required ForumAdminInfo? schoolAdmin,
  required ForumAdminInfo? vocPassAdmin,
}) {
  if (userID == null || userID.isEmpty) return null;
  if (vocPassAdmin?.admin.contains(userID) == true) {
    return ForumBadge.vocPassAdmin;
  }
  if (schoolAdmin?.admin.contains(userID) == true) {
    return ForumBadge.schoolModerator;
  }
  return null;
}

class ForumAvatar extends StatelessWidget {
  final String? url;
  final String fallbackText;
  final double size;

  const ForumAvatar({
    super.key,
    this.url,
    required this.fallbackText,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final initial = fallbackText.isNotEmpty
        ? fallbackText.characters.first.toUpperCase()
        : '?';
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        shape: BoxShape.circle,
      ),
      child: Text(initial,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700)),
    );
    if (url == null) return placeholder;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class ForumTagBadge extends StatelessWidget {
  final ForumTag tag;

  const ForumTagBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(tag.colorHex) ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag.name,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class ForumBadgeChip extends StatelessWidget {
  final ForumBadge badge;

  const ForumBadgeChip({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 11, color: badge.color),
          const SizedBox(width: 3),
          Text(badge.label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: badge.color)),
        ],
      ),
    );
  }
}

/// 圖片格狀預覽，點擊可放大檢視。
class ForumImageGrid extends StatelessWidget {
  final List<String> urls;

  const ForumImageGrid({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < urls.length; i++)
          GestureDetector(
            onTap: () => _openViewer(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                urls[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ForumImageViewer(urls: urls, initialIndex: initialIndex),
    ));
  }
}

class _ForumImageViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const _ForumImageViewer({required this.urls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(urls[i],
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          ),
        ),
      ),
    );
  }
}
