import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../config/school_config.dart';
import 'cache_service.dart';

enum ConfigSource { unknown, api, cache, defaultValue }

class SchoolConfigManager extends ChangeNotifier {
  static final SchoolConfigManager instance = SchoolConfigManager._internal();
  SchoolConfigManager._internal();

  List<SchoolConfig> schools = [];
  List<SchoolConfig> allSchools = [];
  SchoolConfig? selectedSchool;
  bool isLoading = false;
  String? error;
  ConfigSource configSource = ConfigSource.unknown;

  String _currentAppVersion = '0';

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _currentAppVersion = info.version;
    _loadSelectedSchool();
  }

  bool get hasSelectedSchool => selectedSchool != null;

  Future<void> loadSchools() async {
    final url = Uri.parse('${AppConfig.vocPassApiHost}/school');
    if (kDebugMode) {
      print('[vocPass-log] API Request: GET $url');
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.get(url);
      if (kDebugMode) {
        print(
          '[vocPass-log] API Response: $url status=${response.statusCode} body=${response.body}',
        );
      }
      if (response.statusCode != 200) {
        error = '無法取得學校資料';
        await _loadCachedSchools();
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (kDebugMode) {
        print(
          '[vocPass-log] API Response School Datas: $data',
        );
      }
      final parsed = _mapSchoolConfigs(data);
      _setSchools(parsed, source: ConfigSource.api);

      CacheService.instance.prefs.setString('cached_schools', response.body);
      CacheService.instance.prefs.setInt(
        'cached_schools_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      if (selectedSchool != null) {
        final updated = parsed.firstWhere(
          (s) => s.name == selectedSchool!.name,
          orElse: () => selectedSchool!,
        );
        selectSchool(updated);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[vocPass-log] API Error: $url error=$e');
      }
      error = '無法連線至伺服器';
      await _loadCachedSchools();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<SchoolConfig> _mapSchoolConfigs(Map<String, dynamic> data) {
    final list = <SchoolConfig>[];
    data.forEach((name, configValue) {
      if (configValue is Map) {
        list.add(
          SchoolConfig.fromApi(name, configValue.cast<String, dynamic>()),
        );
      }
    });
    return list;
  }

  void _setSchools(List<SchoolConfig> list, {required ConfigSource source}) {
    final versionFiltered = list
        .where((school) => _isSchoolVersionSupported(school.app))
        .toList();
    if (kDebugMode) {
      print('[vocPass-log] _setSchools: 原始數量=${list.length}，版本過濾後=${versionFiltered.length}');
    }
    allSchools = versionFiltered;
    schools = versionFiltered.where((school) {
      if (AppConfig.isDebugBuild) return true;
      return !school.beta;
    }).toList();
    if (kDebugMode) {
      print('[vocPass-log] _setSchools: allSchools=${allSchools.length}，schools(顯示)=${schools.length}');
    }
    configSource = source;
  }

  Future<void> _loadCachedSchools() async {
    final raw = CacheService.instance.prefs.getString('cached_schools');
    if (raw == null || raw.isEmpty) {
      _loadDefaultSchools();
      return;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = _mapSchoolConfigs(data);
      _setSchools(parsed, source: ConfigSource.cache);
    } catch (_) {
      _loadDefaultSchools();
    }
  }

  void _loadDefaultSchools() {
    final defaultRoute = const RouteConfig(
      examResults: '/online/selection_student/{file_name}',
    );

    final defaultList = [
      SchoolConfig(
        name: '鶯歌工商',
        vision: 'v1',
        app: null,
        beta: false,
        api: 'https://eschool.ykvs.ntpc.edu.tw',
        url: const UrlConfig(
          login: '/auth/Online',
          logined: '/online/student/frames.asp',
          root: '/',
        ),
        login: LoginConfig(
          username: const FieldConfig(name: 'LoginName'),
          password: const FieldConfig(name: 'PassString'),
          captcha: const FieldConfig(name: 'ShCaptchaGenCode'),
          captchaImage: const CaptchaImageConfig(
            selector: 'captcha-image',
            type: 'class',
          ),
          button: const ButtonConfig(cssClass: 'loginBtnAdjust'),
          successKeywords: null,
        ),
        route: defaultRoute,
      ),
    ];

    allSchools = defaultList;
    schools = defaultList;
    configSource = ConfigSource.defaultValue;
  }

  void selectSchool(SchoolConfig school) {
    selectedSchool = school;
    CacheService.instance.prefs.setString(
      'selected_school',
      school.toJsonString(),
    );
    notifyListeners();
  }

  void _loadSelectedSchool() {
    final raw = CacheService.instance.prefs.getString('selected_school');
    if (raw == null || raw.isEmpty) return;
    selectedSchool = SchoolConfig.fromJsonString(raw);
  }

  void clearSelectedSchool() {
    selectedSchool = null;
    CacheService.instance.prefs.remove('selected_school');
    notifyListeners();
  }

  bool _isSchoolVersionSupported(String? requiredVersion) {
    return true;
    // if (requiredVersion == null || requiredVersion.trim().isEmpty) return true;
    // return _compareVersion(_currentAppVersion, requiredVersion) >= 0;
  }

  // int _compareVersion(String lhs, String rhs) {
  //   final left = lhs.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  //   final right = rhs.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  //   final maxCount = left.length > right.length ? left.length : right.length;

  //   for (var i = 0; i < maxCount; i++) {
  //     final l = i < left.length ? left[i] : 0;
  //     final r = i < right.length ? right[i] : 0;
  //     if (l < r) return -1;
  //     if (l > r) return 1;
  //   }
  //   return 0;
  // }
}
