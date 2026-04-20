// 「出來玩」When2meet API 服務層

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/w2m_models.dart';
import 'vocpass_auth_service.dart';

class W2MService {
  static final W2MService instance = W2MService._();
  W2MService._();

  String get _base => AppConfig.vocPassApiHost;

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    VocPassAuthService.instance.applyAuthHeader(headers);
    return headers;
  }

  // 取得活動列表（需登入）
  Future<W2MEventListResponse> fetchEvents() async {
    final url = Uri.parse('$_base/api/w2m/events');
    final res = await http.get(url, headers: _headers());
    _validateResponse(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return W2MEventListResponse.fromJson(data);
  }

  // 建立活動，回傳新活動 ID
  Future<String> createEvent({
    required String title,
    required List<String> dates,
    String description = '',
  }) async {
    final url = Uri.parse('$_base/api/w2m/events');
    final res = await http.post(
      url,
      headers: _headers(json: true),
      body: jsonEncode({'title': title, 'dates': dates, 'description': description}),
    );
    _validateResponse(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['id'] as String;
  }

  // 編輯活動（僅 creator）
  Future<void> updateEvent({
    required String id,
    String? title,
    List<String>? dates,
  }) async {
    final url = Uri.parse('$_base/api/w2m/events/$id');
    final bodyMap = <String, dynamic>{};
    if (title != null) bodyMap['title'] = title;
    if (dates != null) bodyMap['dates'] = dates;
    final res = await http.patch(
      url,
      headers: _headers(json: true),
      body: jsonEncode(bodyMap),
    );
    _validateResponse(res);
  }

  // 取得活動詳情（不需登入，但帶 token 讓伺服器識別用戶）
  Future<W2MEvent> fetchEvent(String id) async {
    final url = Uri.parse('$_base/api/w2m/events/$id');
    final res = await http.get(url, headers: _headers());
    _validateResponse(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return W2MEvent.fromJson(data);
  }

  // 提交可用時段
  Future<void> submitAvailability({
    required String eventID,
    required List<String> slots,
  }) async {
    final url = Uri.parse('$_base/api/w2m/events/$eventID/availability');
    final res = await http.put(
      url,
      headers: _headers(json: true),
      body: jsonEncode({'slots': slots}),
    );
    _validateResponse(res);
  }

  // 分享連結
  String shareURL(String eventID) => 'https://vocpass.com/w2m/$eventID';

  void _validateResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = '伺服器錯誤 (${res.statusCode})';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = body['message'] as String? ?? msg;
      } catch (_) {}
      if (kDebugMode) print('[W2M] 錯誤: $msg');
      throw Exception(msg);
    }
  }
}
