import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import 'cache_service.dart';

class VocPassAuthService extends ChangeNotifier {
  static final VocPassAuthService instance = VocPassAuthService._internal();
  VocPassAuthService._internal();

  static const _tokenKey = 'vocpass_auth_token';

  bool isLoggedIn = false;
  VocPassUser? currentUser;

  String? _authToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
    _authToken = token;
  }

  Map<String, String> get _authHeaders {
    if (_authToken != null && _authToken!.isNotEmpty) {
      return {'Authorization': 'Bearer $_authToken', 'Accept': 'application/json'};
    }
    return {'Accept': 'application/json'};
  }

  // Called after OAuth callback with token
  Future<void> handleTokenLogin(String token) async {
    await _saveToken(token);
    try {
      final user = await fetchMe();
      currentUser = user;
      isLoggedIn = true;
      if (user.shareStatus != null) {
        CacheService.instance.isCurriculumSharing = user.shareStatus!;
      }
      notifyListeners();
      if (kDebugMode) print('[VocPassAuth] 登入成功: ${user.displayName}');
    } catch (e) {
      await _saveToken(null);
      if (kDebugMode) print('[VocPassAuth] 取得使用者資料失敗: $e');
    }
  }

  // Restore session on app start
  Future<void> restoreSession() async {
    if (_authToken == null || _authToken!.isEmpty) return;
    try {
      final user = await fetchMe();
      currentUser = user;
      isLoggedIn = true;
      if (user.shareStatus != null) {
        CacheService.instance.isCurriculumSharing = user.shareStatus!;
      }
      notifyListeners();
      if (kDebugMode) print('[VocPassAuth] 已恢復 session: ${user.displayName}');
    } catch (e) {
      await _saveToken(null);
      if (kDebugMode) print('[VocPassAuth] Session 已失效: $e');
    }
  }

  Future<VocPassUser> fetchMe() async {
    final url = Uri.parse('${AppConfig.vocPassApiHost}/auth/me');
    final response = await http.get(url, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw Exception('取得使用者資料失敗 (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VocPassUser.fromJson(json);
  }

  Future<VocPassPublicUser> fetchUser(String username) async {
    final url = Uri.parse('${AppConfig.vocPassApiHost}/api/user/$username');
    final response = await http.get(url, headers: _authHeaders);
    if (response.statusCode != 200) {
      throw Exception('取得使用者資料失敗 (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] ?? json;
    return VocPassPublicUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> updateUser({String? name, String? username}) async {
    final url = Uri.parse('${AppConfig.vocPassApiHost}/api/user/');
    final request = http.MultipartRequest('PATCH', url);
    request.headers.addAll(_authHeaders);
    if (name != null) request.fields['name'] = name;
    if (username != null) request.fields['username'] = username;

    final streamedResponse = await request.send();
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      final msg = (jsonDecode(body) as Map<String, dynamic>?)?['message']?.toString() ?? '更新失敗';
      throw Exception(msg);
    }
    final user = await fetchMe();
    currentUser = user;
    notifyListeners();
  }

  void applyAuthHeader(Map<String, String> headers) {
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
  }

  bool get hasToken => _authToken != null && _authToken!.isNotEmpty;

  void logout() {
    _saveToken(null);
    currentUser = null;
    isLoggedIn = false;
    notifyListeners();
    if (kDebugMode) print('[VocPassAuth] 已登出');
  }
}
