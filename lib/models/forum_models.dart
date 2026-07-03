// 論壇相關資料模型 - 對應 iOS 的 Models.swift 論壇區段

import 'models.dart';

class ForumUser {
  final String id;
  final String name;
  final String username;
  final String? avatar;

  ForumUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatar,
  });

  String get displayName => name.isEmpty ? username : name;
  String? get avatarURL => (avatar != null && avatar!.isNotEmpty) ? avatar : null;

  factory ForumUser.fromJson(Map<String, dynamic> json) {
    final name = JsonUtils.readString(json, ['name']);
    final username = JsonUtils.readString(json, ['username']);
    return ForumUser(
      name: name,
      username: username,
      id: JsonUtils.readString(json, ['id'], defaultValue: username),
      avatar: JsonUtils.readStringNullable(json, ['avatar']),
    );
  }
}

class ForumTag {
  final String name;
  final String? colorHex;
  final bool adminOnly;

  ForumTag({required this.name, this.colorHex, this.adminOnly = false});
}

class ForumTagOption {
  final String name;
  final String? colorHex;
  final bool adminOnly;

  ForumTagOption({required this.name, this.colorHex, this.adminOnly = false});
}

/// 將後端的 tag map（{name: {color, admin_only}}）轉成 [ForumTag] 清單。
List<ForumTag> _parseTagMap(dynamic value) {
  if (value is! Map) return const [];
  final tags = <ForumTag>[];
  value.forEach((key, style) {
    String? color;
    var adminOnly = false;
    if (style is Map) {
      final styleMap = style.cast<String, dynamic>();
      color = JsonUtils.readStringNullable(styleMap, ['color']);
      adminOnly = JsonUtils.readBool(styleMap, ['admin_only', 'adminOnly']);
    }
    tags.add(ForumTag(name: key.toString(), colorHex: color, adminOnly: adminOnly));
  });
  tags.sort((a, b) => a.name.compareTo(b.name));
  return tags;
}

class ForumPost {
  final String id;
  final String? post;
  final String school;
  final String title;
  final String content;
  final bool anonymous;
  final bool pin;
  final List<ForumTag> tags;
  final List<String> images;
  final List<String> likes;
  final ForumUser? user;
  final String created;
  final String updated;

  ForumPost({
    required this.id,
    this.post,
    required this.school,
    required this.title,
    required this.content,
    required this.anonymous,
    required this.pin,
    required this.tags,
    required this.images,
    required this.likes,
    required this.user,
    required this.created,
    required this.updated,
  });

  /// 按讚 / 取消讚與刪除時使用的目標 ID。
  String get likeTargetID => (post != null && post!.isNotEmpty) ? post! : id;

  List<String> get imageURLs =>
      images.where((e) => e.isNotEmpty).toList(growable: false);

  bool isLikedBy(String? userID) =>
      userID != null && userID.isNotEmpty && likes.contains(userID);

  ForumPost copyWithLikes(String userID, {required bool liked}) {
    final newLikes = List<String>.from(likes);
    if (liked) {
      if (!newLikes.contains(userID)) newLikes.add(userID);
    } else {
      newLikes.remove(userID);
    }
    return ForumPost(
      id: id,
      post: post,
      school: school,
      title: title,
      content: content,
      anonymous: anonymous,
      pin: pin,
      tags: tags,
      images: images,
      likes: newLikes,
      user: user,
      created: created,
      updated: updated,
    );
  }

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ForumPost(
      id: JsonUtils.readString(json, ['id']),
      post: JsonUtils.readStringNullable(json, ['post']),
      school: JsonUtils.readString(json, ['school']),
      title: JsonUtils.readString(json, ['title'], defaultValue: '未命名文章'),
      content: JsonUtils.readString(
          json, ['content', 'description', 'body', 'message']),
      anonymous: JsonUtils.readBool(json, ['anonymous']),
      pin: JsonUtils.readBool(json, ['pin']),
      tags: _parseTagMap(json['tag'] ?? json['tags']),
      images: JsonUtils.readStringList(json, ['images', 'image']),
      likes: JsonUtils.readStringList(json, ['likes']),
      user: user is Map ? ForumUser.fromJson(user.cast<String, dynamic>()) : null,
      created: JsonUtils.readString(json, ['created']),
      updated: JsonUtils.readString(json, ['updated']),
    );
  }
}

class ForumMessage {
  final String id;
  final String content;
  final bool anonymous;
  final ForumUser? user;
  final String created;
  final List<String> likes;

  ForumMessage({
    required this.id,
    required this.content,
    required this.anonymous,
    required this.user,
    required this.created,
    required this.likes,
  });

  bool isLikedBy(String? userID) =>
      userID != null && userID.isNotEmpty && likes.contains(userID);

  ForumMessage copyWithLikes(String userID, {required bool liked}) {
    final newLikes = List<String>.from(likes);
    if (liked) {
      if (!newLikes.contains(userID)) newLikes.add(userID);
    } else {
      newLikes.remove(userID);
    }
    return ForumMessage(
      id: id,
      content: content,
      anonymous: anonymous,
      user: user,
      created: created,
      likes: newLikes,
    );
  }

  factory ForumMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return ForumMessage(
      id: JsonUtils.readString(json, ['id']),
      content: JsonUtils.readString(
          json, ['content', 'description', 'body', 'message']),
      anonymous: JsonUtils.readBool(json, ['anonymous']),
      user: user is Map ? ForumUser.fromJson(user.cast<String, dynamic>()) : null,
      created: JsonUtils.readString(json, ['created']),
      likes: JsonUtils.readStringList(json, ['likes']),
    );
  }
}

class ForumPostListData {
  final List<ForumPost> forums;
  final int totalPages;

  ForumPostListData({required this.forums, required this.totalPages});

  factory ForumPostListData.fromJson(Map<String, dynamic> json) {
    final raw = json['forums'];
    return ForumPostListData(
      forums: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ForumPost.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      totalPages: JsonUtils.readInt(json, ['total_pages', 'totalPages'],
          defaultValue: 1),
    );
  }
}

class ForumMessageListData {
  final List<ForumMessage> forums;
  final int totalPages;

  ForumMessageListData({required this.forums, required this.totalPages});

  factory ForumMessageListData.fromJson(Map<String, dynamic> json) {
    final raw = json['forums'];
    return ForumMessageListData(
      forums: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => ForumMessage.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      totalPages: JsonUtils.readInt(json, ['total_pages', 'totalPages'],
          defaultValue: 1),
    );
  }
}

class ForumAdminInfo {
  final String id;
  final String school;
  final String? icon;
  final List<String> admin;

  ForumAdminInfo({
    required this.id,
    required this.school,
    this.icon,
    required this.admin,
  });

  String? get iconURL => (icon != null && icon!.isNotEmpty) ? icon : null;

  factory ForumAdminInfo.fromJson(Map<String, dynamic> json) {
    return ForumAdminInfo(
      id: JsonUtils.readString(json, ['id']),
      school: JsonUtils.readString(json, ['school']),
      icon: JsonUtils.readStringNullable(json, ['icon']),
      admin: JsonUtils.readStringList(json, ['admin']),
    );
  }
}
