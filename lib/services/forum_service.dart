// 論壇 API 服務層 - 對應 iOS APIService.swift 的論壇方法

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/forum_models.dart';
import 'api_service.dart';
import 'vocpass_auth_service.dart';

/// 要上傳的圖片（最多 5 張）。
class ForumImageUpload {
  final Uint8List data;
  final String mimeType;

  ForumImageUpload({required this.data, required this.mimeType});

  String get fileExtension => mimeType == 'image/png' ? 'png' : 'jpg';
}

class ForumService {
  static final ForumService instance = ForumService._();
  ForumService._();

  String get _base => AppConfig.vocPassApiHost;

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (auth) VocPassAuthService.instance.applyAuthHeader(headers);
    return headers;
  }

  String _encodePath(String value) => Uri.encodeComponent(value);

  Never _throwFromResponse(http.Response res) {
    final msg = _extractMessage(res.body);
    throw ApiException(
      ApiErrorType.invalidResponseFormat,
      (msg != null && msg.isNotEmpty) ? msg : '伺服器回應錯誤 (${res.statusCode})',
    );
  }

  String? _extractMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final map = json.cast<String, dynamic>();
        return map['message']?.toString() ?? map['msg']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '資料格式錯誤');
    }
    return json.cast<String, dynamic>();
  }

  // MARK: - 讀取

  /// 取得文章列表。school 傳 "all" 代表全部學校。
  Future<ForumPostListData> fetchPosts({
    required String school,
    int page = 1,
    String? search,
  }) async {
    final query = <String, String>{'page': '$page'};
    final trimmed = search?.trim();
    if (trimmed != null && trimmed.isNotEmpty) query['search'] = trimmed;

    final uri = Uri.parse('$_base/api/forum/${_encodePath(school)}')
        .replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) _throwFromResponse(res);

    final body = _decodeMap(res);
    final data = body['data'];
    if (data is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '文章資料格式錯誤');
    }
    return ForumPostListData.fromJson(data.cast<String, dynamic>());
  }

  Future<ForumMessageListData> fetchMessages({
    required String postID,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_base/api/forum/post/${_encodePath(postID)}/message')
        .replace(queryParameters: {'page': '$page'});
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) _throwFromResponse(res);

    final body = _decodeMap(res);
    final data = body['data'];
    if (data is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '留言資料格式錯誤');
    }
    return ForumMessageListData.fromJson(data.cast<String, dynamic>());
  }

  Future<ForumPostListData> fetchUserPosts({
    required String userID,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_base/api/forum/user/${_encodePath(userID)}')
        .replace(queryParameters: {'page': '$page'});
    final res = await http.get(uri, headers: _headers(auth: true));
    if (res.statusCode != 200) _throwFromResponse(res);

    final body = _decodeMap(res);
    final data = body['data'];
    if (data is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '文章資料格式錯誤');
    }
    return ForumPostListData.fromJson(data.cast<String, dynamic>());
  }

  Future<ForumAdminInfo?> fetchAdminInfo(String school) async {
    final uri = Uri.parse('$_base/api/forum/${_encodePath(school)}/admin');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) return null;
    try {
      final body = _decodeMap(res);
      final data = body['data'];
      if (data is Map) {
        return ForumAdminInfo.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<ForumAdminInfo?> fetchVocPassAdminInfo() => fetchAdminInfo('vocpass');

  Future<List<ForumTagOption>> fetchTags() async {
    final uri = Uri.parse('$_base/api/forum/tags');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) _throwFromResponse(res);

    final body = _decodeMap(res);
    final data = body['data'];
    if (data is! Map) return const [];

    final options = <ForumTagOption>[];
    data.forEach((key, style) {
      String? color;
      var adminOnly = false;
      if (style is Map) {
        final styleMap = style.cast<String, dynamic>();
        color = styleMap['color']?.toString();
        final raw = styleMap['admin_only'] ?? styleMap['adminOnly'];
        adminOnly = raw == true || raw == 1 || raw == 'true';
      }
      options.add(ForumTagOption(
          name: key.toString(), colorHex: color, adminOnly: adminOnly));
    });
    options.sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  // MARK: - 寫入

  Future<void> createPost({
    required String school,
    required String title,
    required String content,
    bool anonymous = false,
    bool pin = false,
    List<String> tags = const [],
    List<ForumImageUpload> images = const [],
  }) async {
    final uri = Uri.parse('$_base/api/forum/post');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers(auth: true));
    request.fields['school'] = school;
    request.fields['title'] = title;
    request.fields['content'] = content;
    request.fields['anonymous'] = anonymous ? 'true' : 'false';
    request.fields['pin'] = pin ? 'true' : 'false';
    if (tags.isNotEmpty) request.fields['tag'] = tags.join(',');

    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      request.files.add(http.MultipartFile.fromBytes(
        'images',
        image.data,
        filename: 'forum_$i.${image.fileExtension}',
        contentType: MediaType.parse(image.mimeType),
      ));
    }

    await _sendMultipart(request, '發文失敗');
  }

  Future<void> createMessage({
    required String postID,
    required String content,
    bool anonymous = false,
  }) async {
    final uri =
        Uri.parse('$_base/api/forum/post/${_encodePath(postID)}/message');
    final headers = _headers(auth: true)
      ..['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8';
    final res = await http.post(
      uri,
      headers: headers,
      body: {'content': content, 'anonymous': anonymous ? 'true' : 'false'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  Future<void> deletePost(String postID) async {
    final uri = Uri.parse('$_base/api/forum/post/${_encodePath(postID)}');
    final res = await http.delete(uri, headers: _headers(auth: true));
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  Future<void> deleteMessage(String messageID) async {
    final uri = Uri.parse('$_base/api/forum/message/${_encodePath(messageID)}');
    final res = await http.delete(uri, headers: _headers(auth: true));
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  Future<void> setPostLike({required String postID, required bool liked}) async {
    final uri = Uri.parse('$_base/api/forum/post/${_encodePath(postID)}/like');
    final headers = _headers(auth: true);
    final res = liked
        ? await http.post(uri, headers: headers)
        : await http.delete(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  Future<void> setMessageLike(
      {required String messageID, required bool liked}) async {
    final uri =
        Uri.parse('$_base/api/forum/message/${_encodePath(messageID)}/like');
    final headers = _headers(auth: true);
    final res = liked
        ? await http.post(uri, headers: headers)
        : await http.delete(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  /// 檢舉文章或留言。對應後端 /api/report 的 forum_id / forum_message_id 欄位。
  Future<void> report({
    String? forumPostID,
    String? forumMessageID,
    required String reason,
    String? description,
  }) async {
    final uri = Uri.parse('$_base/api/report');
    final body = <String, dynamic>{'reason': reason};
    if (forumPostID != null) body['forum_id'] = forumPostID;
    if (forumMessageID != null) body['forum_message_id'] = forumMessageID;
    final trimmed = description?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['description'] = trimmed;

    final headers = _headers(auth: true)
      ..['Content-Type'] = 'application/json';
    final res = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) _throwFromResponse(res);
  }

  Future<void> _sendMultipart(
      http.MultipartRequest request, String fallbackMessage) async {
    if (kDebugMode) {
      print('[Forum] ${request.method} ${request.url} fields=${request.fields}');
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = _extractMessage(res.body);
      throw ApiException(
        ApiErrorType.invalidResponseFormat,
        (msg != null && msg.isNotEmpty) ? msg : fallbackMessage,
      );
    }
  }
}
