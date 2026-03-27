import 'dart:convert';

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/school_config.dart';
import '../models/models.dart';
import 'cache_service.dart';
import 'html_parser.dart';
import 'school_config_manager.dart';
import 'vocpass_auth_service.dart';

class AppCookie {
  final String name;
  final String value;

  AppCookie({required this.name, required this.value});
}

enum ApiErrorType {
  noSchoolSelected,
  sessionExpired,
  featureNotSupported,
  invalidResponseFormat,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;

  ApiException(this.type, this.message);

  @override
  String toString() => message;
}

class ApiService extends ChangeNotifier {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  static const _weeksPerSemester = 18;

  List<AppCookie> cookies = [];
  bool isLoggedIn = false;

  String get cookieString =>
      cookies.map((c) => '${c.name}=${c.value}').join('; ');

  void setCookies(List<AppCookie> value) {
    cookies = value;
    notifyListeners();
  }

  void markLoggedIn() {
    isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    cookies = [];
    isLoggedIn = false;
    CacheService.instance.clearLoginCredentials();
    notifyListeners();
  }

  SchoolConfig _selectedSchool() {
    final school = SchoolConfigManager.instance.selectedSchool;
    if (school == null) {
      throw ApiException(ApiErrorType.noSchoolSelected, '未選擇學校');
    }
    return school;
  }

  Future<http.Response> _proxyGetData(String path,
      {List<MapEntry<String, String>> extraQuery = const []}) async {
    final school = _selectedSchool();

    if (cookieString.isEmpty) {
      throw ApiException(ApiErrorType.sessionExpired, '登入狀態已過期');
    }

    final baseUrl = '${AppConfig.vocPassApiHost}/api/${school.vision}/$path';
    final queryParameters = <String, String>{
      'school_name': school.name,
    };
    for (final item in extraQuery) {
      queryParameters[item.key] = item.value;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParameters);

    if (kDebugMode) {
      print('[vocPass-log] API Request: GET $uri headers=${{'Cookie': cookieString, 'Accept': 'application/json'}}');
    }
    final response = await http.get(
      uri,
      headers: {
        'Cookie': cookieString,
        'Accept': 'application/json',
      },
    );
    if (kDebugMode) {
      print('[vocPass-log] API Response: $uri status=${response.statusCode} body=${response.body}');
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw ApiException(ApiErrorType.featureNotSupported, '此功能尚未支援');
      }
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }

    return response;
  }

  void _checkApiStatus(dynamic json) {
    if (json is! Map) return;
    final map = json.cast<String, dynamic>();
    final code = JsonUtils.readInt(map, ['code', 'status'], defaultValue: 200);
    final message =
        JsonUtils.readString(map, ['message', 'msg', 'detail', 'error']);

    if (code == 404 || message.toLowerCase().contains('not implemented')) {
      throw ApiException(ApiErrorType.featureNotSupported, '此功能尚未支援');
    }
    if (code == 401 || code == 403) {
      throw ApiException(ApiErrorType.sessionExpired, '登入狀態已過期');
    }
  }

  dynamic _extractPayload(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json.containsKey('data')) return json['data'];
      if (json.containsKey('result')) return json['result'];
      if (json.containsKey('payload')) return json['payload'];
      return json;
    }
    return json;
  }

  Future<(List<MeritDemeritRecord>, List<MeritDemeritRecord>)>
      fetchMeritDemeritRecords() async {
    final response = await _proxyGetData('merit_demerit');
    final json = jsonDecode(response.body);

    _checkApiStatus(json);
    final payload = _extractPayload(json);

    if (payload is List && payload.isNotEmpty && payload.first is List) {
      final merits = (payload.isNotEmpty)
          ? (payload[0] as List)
              .whereType<Map>()
              .map((e) => MeritDemeritRecord.fromJson(
                  e.cast<String, dynamic>()))
              .toList()
          : <MeritDemeritRecord>[];
      final demerits = (payload.length > 1)
          ? (payload[1] as List)
              .whereType<Map>()
              .map((e) => MeritDemeritRecord.fromJson(
                  e.cast<String, dynamic>()))
              .toList()
          : <MeritDemeritRecord>[];
      return (merits, demerits);
    }

    if (payload is Map) {
      final map = payload.cast<String, dynamic>();
      final merits = _extractMeritList(map, [
        'merits',
        'merit',
        'rewards',
        'reward',
        'awards',
        'award',
        '獎勵',
      ]);
      final demerits = _extractMeritList(map, [
        'demerits',
        'demerit',
        'punishments',
        'punishment',
        'penalties',
        'penalty',
        '懲罰',
      ]);
      return (merits, demerits);
    }

    if (payload is List) {
      final list = payload
          .whereType<Map>()
          .map((e) => MeritDemeritRecord.fromJson(e.cast<String, dynamic>()))
          .toList();
      return (list, <MeritDemeritRecord>[]);
    }

    throw ApiException(ApiErrorType.invalidResponseFormat, '資料格式錯誤');
  }

  List<MeritDemeritRecord> _extractMeritList(
      Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => MeritDemeritRecord.fromJson(
                e.cast<String, dynamic>()))
            .toList();
      }
    }
    return [];
  }

  Future<TimetableData> fetchTimetableData(
      {String classNumber = '212', bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.instance.getCachedTimetable();
      if (cached != null) return cached;
    }

    final response = await _proxyGetData('curriculum');
    final json = jsonDecode(response.body);
    _checkApiStatus(json);
    final payload = _extractPayload(json);

    if (payload is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '課表資料格式錯誤');
    }

    final curriculum = payload.map((key, value) => MapEntry(
          key.toString(),
          CourseInfo.fromJson((value as Map).cast<String, dynamic>()),
        ));

    final entries = <TimetableEntry>[];
    for (final entry in curriculum.entries) {
      for (final schedule in entry.value.schedule) {
        entries.add(TimetableEntry(
          weekday: schedule.weekday,
          period: schedule.period,
          subject: entry.key,
        ));
      }
    }

    final timetable = TimetableData(
      entries: entries,
      periodTimes: const {},
      curriculum: curriculum,
    );
    CacheService.instance.cacheTimetable(timetable);
    CacheService.instance.cacheCurriculum(curriculum);
    return timetable;
  }

  Future<Map<String, CourseInfo>> fetchCurriculum(
      {String classNumber = '212', bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.instance.getCachedTimetable();
      if (cached != null) return cached.curriculum;
    }
    final timetable =
        await fetchTimetableData(classNumber: classNumber, forceRefresh: forceRefresh);
    return timetable.curriculum;
  }

  Future<(List<AbsenceRecord>, AttendanceStatistics, SemesterInfo?)>
      fetchAttendance() async {
    final response = await _proxyGetData('attendance');
    final json = jsonDecode(response.body);
    _checkApiStatus(json);
    final payload = _extractPayload(json);

    if (payload is! List) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '缺曠資料格式錯誤');
    }

    final records = payload
        .whereType<Map>()
        .map((e) => AbsenceRecord.fromJson(e.cast<String, dynamic>()))
        .toList();

    final statistics = _computeAttendanceStatistics(records);
    final semesterInfo = _currentSemesterInfo();
    return (records, statistics, semesterInfo);
  }

  AttendanceStatistics _computeAttendanceStatistics(
      List<AbsenceRecord> records) {
    final firstSemester = <String, String>{};
    final secondSemester = <String, String>{};

    var truancy = 0;
    var personalLeave = 0;
    var sickLeave = 0;
    var officialLeave = 0;

    const mapping = {
      '曠': '曠課',
      '事': '事假',
      '病': '病假',
      '公': '公假',
    };

    for (final record in records) {
      final key = mapping[record.status] ?? record.status;
      if (record.academicYear == '上') {
        final current = int.tryParse(firstSemester[key] ?? '0') ?? 0;
        firstSemester[key] = (current + 1).toString();
      } else {
        final current = int.tryParse(secondSemester[key] ?? '0') ?? 0;
        secondSemester[key] = (current + 1).toString();
      }

      switch (record.status) {
        case '曠':
          truancy += 1;
          break;
        case '事':
          personalLeave += 1;
          break;
        case '病':
          sickLeave += 1;
          break;
        case '公':
          officialLeave += 1;
          break;
        default:
          break;
      }
    }

    return AttendanceStatistics(
      firstSemester: firstSemester,
      secondSemester: secondSemester,
      total: AttendanceTotals(
        truancy: truancy,
        personalLeave: personalLeave,
        sickLeave: sickLeave,
        officialLeave: officialLeave,
      ),
      statisticsDate: '',
    );
  }

  SemesterInfo _currentSemesterInfo() {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final schoolYear = month >= 8 ? (year - 1911) : (year - 1912);
    final semester = month >= 8 ? '1' : '2';
    return SemesterInfo(schoolYear: schoolYear.toString(), semester: semester);
  }

  Future<GradeData> fetchYearScore({int year = 1}) async {
    final semester = year.clamp(1, 3);
    final response = await _proxyGetData('semester_scores', extraQuery: [
      MapEntry('semester', semester.toString()),
    ]);
    final json = jsonDecode(response.body);
    _checkApiStatus(json);
    final payload = _extractPayload(json);

    if (payload is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '成績資料格式錯誤');
    }
    return GradeData.fromJson(payload.cast<String, dynamic>());
  }

  Future<List<ExamMenuItem>> fetchExamMenu({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.instance.getCachedExamMenu();
      if (cached != null) return cached;
    }

    final school = _selectedSchool();
    if (school.route.examResults == null) {
      throw ApiException(ApiErrorType.featureNotSupported, '此功能尚未支援');
    }

    final response = await _proxyGetData('exam_menu');
    final json = jsonDecode(response.body);
    _checkApiStatus(json);
    final payload = _extractPayload(json);

    if (payload is! List) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '考試選單格式錯誤');
    }

    final items = payload
        .whereType<Map>()
        .map((e) {
          final item = ExamMenuItem.fromJson(e.cast<String, dynamic>());
          final path = school.route.examResults!.replaceAll('{file_name}', item.url);
          return ExamMenuItem(
            name: item.name,
            url: item.url,
            fullUrl: '${school.api}$path',
          );
        })
        .toList();

    CacheService.instance.cacheExamMenu(items);
    return items;
  }

  Future<ExamScoreData> fetchExamScore(String url) async {
    final html = await _requestHtml(url);
    if (html.contains('重新登入')) {
      isLoggedIn = false;
      notifyListeners();
      throw ApiException(ApiErrorType.sessionExpired, '登入狀態已過期');
    }
    return HtmlParser.parseExamScores(html);
  }

  Future<(AttendanceStatistics, List<SubjectAbsence>)>
      fetchAttendanceWithCurriculum({String classNumber = '212'}) async {
    final attendanceFuture = fetchAttendance();
    final curriculumFuture = fetchCurriculum(classNumber: classNumber);

    final attendanceResult = await attendanceFuture;
    Map<String, CourseInfo>? curriculum;
    try {
      curriculum = await curriculumFuture;
    } catch (_) {
      curriculum = null;
    }

    final subjectAbsences = curriculum == null
        ? <SubjectAbsence>[]
        : _calculateSubjectAbsences(
            curriculum: curriculum,
            absenceRecords: attendanceResult.$1,
            weeksPerSemester: _weeksPerSemester,
            currentSemester: attendanceResult.$3?.semester,
          );

    return (attendanceResult.$2, subjectAbsences);
  }

  List<SubjectAbsence> _calculateSubjectAbsences({
    required Map<String, CourseInfo> curriculum,
    required List<AbsenceRecord> absenceRecords,
    required int weeksPerSemester,
    String? currentSemester,
  }) {
    final courseMapping = <String, String>{};
    for (final entry in curriculum.entries) {
      for (final schedule in entry.value.schedule) {
        final key = '${schedule.weekday}-${schedule.period}';
        courseMapping[key] = entry.key;
      }
    }

    final absenceCount = <String, ({int truancy, int personalLeave})>{};
    const numberMap = {
      '1': '一',
      '2': '二',
      '3': '三',
      '4': '四',
      '5': '五',
      '6': '六',
      '7': '七',
    };

    for (final record in absenceRecords) {
      if (currentSemester != null) {
        final chineseSemester = currentSemester == '1' ? '上' : '下';
        if (record.academicYear != chineseSemester) {
          continue;
        }
      }
      final weekday = record.weekday;
      final period = numberMap[record.period] ?? record.period;
      final subject = courseMapping['$weekday-$period'];
      if (subject == null) continue;

      final current = absenceCount[subject] ?? (truancy: 0, personalLeave: 0);
      if (record.status == '曠') {
        absenceCount[subject] =
            (truancy: current.truancy + 1, personalLeave: current.personalLeave);
      } else if (record.status == '事') {
        absenceCount[subject] =
            (truancy: current.truancy, personalLeave: current.personalLeave + 1);
      }
    }

    final result = <SubjectAbsence>[];
    for (final entry in curriculum.entries) {
      final totalClasses = entry.value.count * weeksPerSemester;
      final counts = absenceCount[entry.key] ?? (truancy: 0, personalLeave: 0);
      final total = counts.truancy + counts.personalLeave;
      final percentage = totalClasses > 0 ? ((total / totalClasses) * 100).round() : 0;

      result.add(SubjectAbsence(
        subject: entry.key,
        truancy: counts.truancy,
        personalLeave: counts.personalLeave,
        total: total,
        totalClasses: totalClasses,
        percentage: percentage,
      ));
    }

    result.sort((a, b) => b.percentage.compareTo(a.percentage));
    return result;
  }

  Future<List<NoticeItem>> fetchNotices() async {
    final school = _selectedSchool();
    final noticeConfig = school.notice;
    if (noticeConfig == null) {
      throw ApiException(ApiErrorType.featureNotSupported, '此功能尚未支援');
    }

    final uri = Uri.parse(
      '${AppConfig.vocPassApiHost}/api/${noticeConfig.vision}/notice',
    ).replace(queryParameters: {'school_name': school.name});

    final headers = <String, String>{'Accept': 'application/json'};
    if (cookieString.isNotEmpty) headers['Cookie'] = cookieString;

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 404) {
      throw ApiException(ApiErrorType.featureNotSupported, '此功能尚未支援');
    }
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }

    final json = jsonDecode(response.body);
    final data = json is Map ? (json['data'] ?? json) : json;
    if (data is! List) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '公告資料格式錯誤');
    }
    return data
        .whereType<Map>()
        .map((e) => NoticeItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<TimetableData> fetchSharedCurriculum(String username) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/api/curriculum/$username');
    final headers = <String, String>{'Accept': 'application/json'};
    VocPassAuthService.instance.applyAuthHeader(headers);

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 404) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '未找到用戶或用戶未分享');
    }
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }

    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '課表資料格式錯誤');
    }

    final curriculum = json.map((key, value) => MapEntry(
          key.toString(),
          CourseInfo.fromJson((value as Map).cast<String, dynamic>()),
        ));

    final entries = <TimetableEntry>[];
    for (final entry in curriculum.entries) {
      for (final schedule in entry.value.schedule) {
        entries.add(TimetableEntry(
          weekday: schedule.weekday,
          period: schedule.period,
          subject: entry.key,
        ));
      }
    }

    return TimetableData(
      entries: entries,
      periodTimes: const {},
      curriculum: curriculum,
    );
  }

  Future<void> setCurriculumSharing(bool share) async {
    final cachedTimetable = CacheService.instance.getCachedTimetable();
    final body = cachedTimetable != null
        ? cachedTimetable.curriculum.map((key, value) => MapEntry(key, {
              'count': value.count,
              'schedule': value.schedule
                  .map((e) => {'weekday': e.weekday, 'period': e.period})
                  .toList(),
            }))
        : <String, dynamic>{};

    final shareValue = share ? 1 : 0;
    final uri = Uri.parse(
        '${AppConfig.vocPassApiHost}/api/share_curriculum?share_status=$shareValue');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    VocPassAuthService.instance.applyAuthHeader(headers);

    final response = await http.post(uri,
        headers: headers, body: jsonEncode(body));
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '設定失敗');
    }
    CacheService.instance.isCurriculumSharing = share;
  }

  // MARK: - 餐廳

  Future<List<Restaurant>> fetchRestaurants(String school) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/')
        .replace(queryParameters: {'school': school});
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }
    final json = jsonDecode(response.body);
    final items = json['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => Restaurant.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<RestaurantEvaluation>> fetchRestaurantEvaluations(String id) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/evaluate/$id')
        .replace(queryParameters: {'per_page': '50'});
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }
    final json = jsonDecode(response.body);
    final items = json['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => RestaurantEvaluation.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<String> createRestaurant({
    required String school,
    required String name,
    required double lat,
    required double lon,
    String? address,
  }) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/');
    final body = <String, dynamic>{
      'school': school,
      'name': name,
      'map': {'lon': lon, 'lat': lat},
    };
    if (address != null && address.isNotEmpty) body['address'] = address;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    VocPassAuthService.instance.applyAuthHeader(headers);

    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '新增失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
    final json = jsonDecode(response.body);
    return (json is Map ? json['id']?.toString() : null) ?? '';
  }

  Future<void> createEvaluation({
    required String restaurantID,
    required String title,
    required String description,
    required int score,
  }) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/evaluate');
    final body = {
      'restaurant': restaurantID,
      'title': title,
      'description': description,
      'score': score,
    };
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    VocPassAuthService.instance.applyAuthHeader(headers);

    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '送出失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
  }

  Future<void> deleteRestaurant(String id) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/$id');
    final headers = <String, String>{'Accept': 'application/json'};
    VocPassAuthService.instance.applyAuthHeader(headers);
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '刪除失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
  }

  Future<void> deleteEvaluation(String id) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/evaluate/$id');
    final headers = <String, String>{'Accept': 'application/json'};
    VocPassAuthService.instance.applyAuthHeader(headers);
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '刪除失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
  }

  Future<List<RestaurantMenu>> fetchRestaurantMenu(String id) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/menu/$id')
        .replace(queryParameters: {'per_page': '50'});
    final response = await http.get(uri, headers: {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }
    final json = jsonDecode(response.body);
    final items = json['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => RestaurantMenu.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> deleteRestaurantMenu(String id) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/restaurant/menu/$id');
    final headers = <String, String>{'Accept': 'application/json'};
    VocPassAuthService.instance.applyAuthHeader(headers);
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '刪除失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
  }

  Future<void> reportContent({
    String? restaurantID,
    String? restaurantEvaluateID,
    String? restaurantMenuID,
    required String reason,
    String? description,
  }) async {
    final uri = Uri.parse('${AppConfig.vocPassApiHost}/api/report');
    final body = <String, dynamic>{'reason': reason};
    if (restaurantID != null) body['restaurant_id'] = restaurantID;
    if (restaurantEvaluateID != null) body['restaurant_evaluate_id'] = restaurantEvaluateID;
    if (restaurantMenuID != null) body['restaurant_menu_id'] = restaurantMenuID;
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    VocPassAuthService.instance.applyAuthHeader(headers);
    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _extractErrorMessage(response.body) ?? '檢舉失敗';
      throw ApiException(ApiErrorType.invalidResponseFormat, msg);
    }
  }

  String? _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json['message']?.toString() ?? json['msg']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<String> _requestHtml(String url) async {
    final requestUrl = Uri.tryParse(url);
    if (requestUrl == null) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '網址格式錯誤');
    }

    if (kDebugMode) {
      print('[vocPass-log] API Request: GET $requestUrl headers=${{'accept-encoding': 'gzip, deflate, br', 'accept-language': 'zh-TW,zh;q=0.9,en;q=0.8', 'cache-control': 'no-cache', 'cookie': cookieString, 'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'}}');
    }
    final response = await http.get(requestUrl, headers: {
      'accept-encoding': 'gzip, deflate, br',
      'accept-language': 'zh-TW,zh;q=0.9,en;q=0.8',
      'cache-control': 'no-cache',
      'cookie': cookieString,
      'user-agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });
    if (kDebugMode) {
      print('[vocPass-log] API Response: $requestUrl status=${response.statusCode} body=${response.body}');
    }

    if (response.statusCode != 200) {
      throw ApiException(ApiErrorType.invalidResponseFormat, '伺服器回應錯誤');
    }

    final bytes = response.bodyBytes;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return await CharsetConverter.decode('big5', bytes);
      } catch (_) {
        throw ApiException(ApiErrorType.invalidResponseFormat, '無法解析內容');
      }
    }
  }
}
