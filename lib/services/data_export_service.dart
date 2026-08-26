import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'school_config_manager.dart';

/// 匯出過程中單一區段的狀態，用來在畫面上顯示每個項目的進度。
enum ExportSectionStatus { pending, running, success, skipped, failed }

class ExportSection {
  final String key;
  final String title;
  ExportSectionStatus status;

  /// 成功時的資料筆數（課表為科目數、學期成績為學年數）。
  int count;

  /// 失敗或略過的原因，顯示在項目下方。
  String? message;

  ExportSection({
    required this.key,
    required this.title,
    this.status = ExportSectionStatus.pending,
    this.count = 0,
    this.message,
  });
}

/// 匯出結果：JSON 內容 + 建議檔名 + 各區段狀態。
class ExportResult {
  final String json;
  final String fileName;
  final List<ExportSection> sections;

  ExportResult({
    required this.json,
    required this.fileName,
    required this.sections,
  });
}

/// 校務資料匯出。
///
/// 直接保留上游 API 的原始 payload 形狀（而非 App 內部 model 的形狀），
/// 讓匯出的 JSON 與線上檢視工具 (vocpass.com/export) 的 schema 一致。
class DataExportService {
  static const int schemaVersion = 1;

  static final DataExportService instance = DataExportService._internal();
  DataExportService._internal();

  /// 依序抓取各區段資料並組成匯出用的 JSON。
  ///
  /// [onProgress] 會在每個區段狀態變化時被呼叫，供 UI 更新進度。
  Future<ExportResult> export({
    required ApiService api,
    void Function(List<ExportSection> sections)? onProgress,
  }) async {
    final school = SchoolConfigManager.instance.selectedSchool;
    if (school == null) {
      throw ApiException(ApiErrorType.noSchoolSelected, '未選擇學校');
    }

    final sections = [
      ExportSection(key: 'attendance', title: '缺曠'),
      ExportSection(key: 'curriculum', title: '課表'),
      ExportSection(key: 'exams', title: '考試成績'),
      ExportSection(key: 'merit_demerit', title: '獎懲'),
      ExportSection(key: 'semester_scores', title: '學期成績'),
    ];
    ExportSection sectionFor(String key) =>
        sections.firstWhere((s) => s.key == key);

    void notify() => onProgress?.call(sections);

    // 各區段互相獨立：單一區段失敗（例如學校不支援）不應中斷整份匯出。
    final data = <String, dynamic>{};

    Future<void> run(String key, Future<Object?> Function() fetch) async {
      final section = sectionFor(key);
      section.status = ExportSectionStatus.running;
      notify();
      try {
        final value = await fetch();
        if (value == null) {
          section.status = ExportSectionStatus.skipped;
          notify();
          return;
        }
        data[key] = value;
        section.count =
            value is List ? value.length : (value is Map ? value.length : 0);
        if (section.count == 0) {
          section.status = ExportSectionStatus.skipped;
          section.message = '沒有資料';
        } else {
          section.status = ExportSectionStatus.success;
        }
      } on ApiException catch (e) {
        section.status = e.type == ApiErrorType.featureNotSupported
            ? ExportSectionStatus.skipped
            : ExportSectionStatus.failed;
        section.message = e.message;
      } catch (e) {
        section.status = ExportSectionStatus.failed;
        section.message = '$e';
        if (kDebugMode) print('[DataExport] $key 失敗: $e');
      }
      notify();
    }

    await run('attendance', () => api.fetchRawPayload('attendance'));
    await run('curriculum', () => api.fetchRawPayload('curriculum'));
    await run('exams', () => _fetchExams(api));
    await run('merit_demerit', () => api.fetchRawPayload('merit_demerit'));
    await run('semester_scores', () => _fetchSemesterScores(api));

    // 未成功的區段仍以空值寫入，讓輸出的 schema 保持固定。
    data.putIfAbsent('attendance', () => const []);
    data.putIfAbsent('curriculum', () => const <String, dynamic>{});
    data.putIfAbsent('exams', () => const []);
    data.putIfAbsent('merit_demerit', () => const []);
    data.putIfAbsent('semester_scores', () => const <String, dynamic>{});

    final now = DateTime.now();
    data['_meta'] = {
      'app_version': await _appVersion(),
      'exported_at': '${now.toUtc().toIso8601String().split('.').first}Z',
      'schema_version': schemaVersion,
      'school': school.name,
    };

    // 與範例檔一致：key 依字母排序、縮排 2 空白。
    final sortedKeys = data.keys.toList()..sort();
    final ordered = <String, dynamic>{};
    for (final key in sortedKeys) {
      ordered[key] = data[key];
    }
    final json = const JsonEncoder.withIndent('  ').convert(ordered);

    return ExportResult(
      json: json,
      fileName: 'VocPass_${school.name}_${_timestamp(now)}.json',
      sections: sections,
    );
  }

  /// 逐一抓取考試選單中的每份成績。學校若未支援會拋出 featureNotSupported。
  Future<List<dynamic>> _fetchExams(ApiService api) async {
    final menu = await api.fetchExamMenu(forceRefresh: true);
    final exams = <dynamic>[];
    for (final item in menu) {
      try {
        final score = await api.fetchExamScore(item.fullUrl);
        exams.add({
          'exam_info': score.examInfo,
          'name': item.name,
          'student_info': {
            'class_name': score.studentInfo.className,
            'name': score.studentInfo.name,
            'student_id': score.studentInfo.studentId,
          },
          'subjects': [
            for (final s in score.subjects)
              {
                'class_average': s.classAverage,
                'score': s.personalScore,
                'subject': s.subject,
              },
          ],
          'summary': {
            'average_score': score.summary.averageScore,
            'class_rank': score.summary.classRank,
            'department_rank': score.summary.departmentRank,
            'total_score': score.summary.totalScore,
          },
        });
      } catch (e) {
        // 單場考試抓取失敗不影響其他場次。
        if (kDebugMode) print('[DataExport] 考試 ${item.name} 失敗: $e');
      }
    }
    return exams;
  }

  /// 學期成績以學年 1/2/3 為 key，對應原系統的三個學年。
  Future<Map<String, dynamic>> _fetchSemesterScores(ApiService api) async {
    final result = <String, dynamic>{};
    for (var year = 1; year <= 3; year++) {
      try {
        final payload = await api.fetchRawPayload(
          'semester_scores',
          extraQuery: [MapEntry('semester', '$year')],
        );
        if (payload is Map && payload.isNotEmpty) {
          result['$year'] = payload;
        }
      } on ApiException catch (e) {
        // 尚未就讀的學年可能回傳錯誤；登入過期則要讓外層知道。
        if (e.type == ApiErrorType.sessionExpired) rethrow;
        if (kDebugMode) print('[DataExport] 學年 $year 失敗: ${e.message}');
      } catch (e) {
        if (kDebugMode) print('[DataExport] 學年 $year 失敗: $e');
      }
    }
    return result;
  }

  /// 將 JSON 寫入暫存目錄，回傳可供分享的檔案。
  Future<File> writeToFile(ExportResult result) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${result.fileName}');
    await file.writeAsString(result.json, encoding: utf8, flush: true);
    return file;
  }

  Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  String _timestamp(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
