import 'dart:convert';

class ApiResponse<T> {
  final int code;
  final String message;
  final T data;

  ApiResponse({required this.code, required this.message, required this.data});

  static ApiResponse<T> fromJson<T>(
    dynamic json,
    T Function(dynamic json) parseData,
  ) {
    int resolvedCode = 200;
    String resolvedMessage = '';
    dynamic resolvedData;

    if (json is Map<String, dynamic>) {
      final alt = json;

      resolvedCode = JsonUtils.readInt(alt, [
        'code',
        'status',
      ], defaultValue: resolvedCode);

      if (alt.containsKey('success')) {
        final success = JsonUtils.readBool(alt, ['success'], defaultValue: true);
        resolvedCode = success ? 200 : 0;
      }

      resolvedMessage = JsonUtils.readString(alt, [
        'message',
        'msg',
        'detail',
        'error',
      ], defaultValue: resolvedMessage);

      if (alt.containsKey('data')) {
        resolvedData = alt['data'];
      } else if (alt.containsKey('result')) {
        resolvedData = alt['result'];
      } else if (alt.containsKey('payload')) {
        resolvedData = alt['payload'];
      } else {
        resolvedData = alt;
      }
    } else {
      resolvedData = json;
    }

    return ApiResponse(
      code: resolvedCode,
      message: resolvedMessage,
      data: parseData(resolvedData),
    );
  }
}

class JsonUtils {
  static String readString(Map<String, dynamic> json, List<String> keys,
      {String defaultValue = ''}) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      if (value is String) return value;
      if (value is num || value is bool) return value.toString();
    }
    return defaultValue;
  }

  static String? readStringNullable(Map<String, dynamic> json, List<String> keys) {
    final value = readString(json, keys, defaultValue: '');
    return value.isEmpty ? null : value;
  }

  static int readInt(Map<String, dynamic> json, List<String> keys,
      {int defaultValue = 0}) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      if (value is bool) return value ? 1 : 0;
    }
    return defaultValue;
  }

  static bool readBool(Map<String, dynamic> json, List<String> keys,
      {bool defaultValue = false}) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        switch (value.trim().toLowerCase()) {
          case 'true':
          case '1':
          case 'yes':
          case 'y':
          case 'ok':
          case 'success':
            return true;
          default:
            return false;
        }
      }
    }
    return defaultValue;
  }

  static List<String> readStringList(Map<String, dynamic> json, List<String> keys,
      {List<String> defaultValue = const []}) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (value is String) {
        return value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return defaultValue;
  }

  static Map<String, String> readStringMap(Map<String, dynamic> json, List<String> keys,
      {Map<String, String> defaultValue = const {}}) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final value = json[key];
      if (value == null) continue;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    return defaultValue;
  }
}

class MeritDemeritRecord {
  final String id;
  final String dateOccurred;
  final String dateApproved;
  final String reason;
  final String action;
  final String? dateRevoked;
  final String year;

  MeritDemeritRecord({
    required this.dateOccurred,
    required this.dateApproved,
    required this.reason,
    required this.action,
    required this.dateRevoked,
    required this.year,
  }) : id = '$dateOccurred-$action-$reason-$dateApproved';

  factory MeritDemeritRecord.fromJson(Map<String, dynamic> json) {
    final dateOccurred = JsonUtils.readString(json, [
      'date_occurred',
      'dateOccurred',
    ]);
    final dateApproved = JsonUtils.readString(json, [
      'date_approved',
      'dateApproved',
    ]);
    final reason = JsonUtils.readString(json, ['reason']);
    final action = JsonUtils.readString(json, [
      'action',
      'content',
      'type',
    ]);
    final dateRevoked = JsonUtils.readStringNullable(json, [
      'date_revoked',
      'dateRevoked',
    ]);
    final year = JsonUtils.readString(json, [
      'year',
      'school_year',
      'academic_year',
    ]);
    return MeritDemeritRecord(
      dateOccurred: dateOccurred,
      dateApproved: dateApproved,
      reason: reason,
      action: action,
      dateRevoked: dateRevoked,
      year: year,
    );
  }
}

class AbsenceRecord {
  final String id;
  final String academicYear;
  final String date;
  final String weekday;
  final String period;
  final String status;

  AbsenceRecord({
    required this.academicYear,
    required this.date,
    required this.weekday,
    required this.period,
    required this.status,
  }) : id = '$date-$weekday-$period-$status';

  factory AbsenceRecord.fromJson(Map<String, dynamic> json) {
    return AbsenceRecord(
      academicYear: JsonUtils.readString(json, [
        'academic_term',
        'academicTerm',
        'semester',
        'term',
        'school_semester',
      ]),
      date: JsonUtils.readString(json, [
        'date',
        'date_occurred',
      ]),
      weekday: JsonUtils.readString(json, [
        'weekday',
        'day',
        'week',
        'week_day',
      ]),
      period: JsonUtils.readString(json, [
        'period',
        'section',
        'class_period',
      ]),
      status: JsonUtils.readString(json, [
        'cell',
        'attendance_type',
        'type',
        'reason',
        'status',
      ]),
    );
  }
}

class AttendanceStatistics {
  final Map<String, String> firstSemester;
  final Map<String, String> secondSemester;
  final AttendanceTotals total;
  final String statisticsDate;

  AttendanceStatistics({
    required this.firstSemester,
    required this.secondSemester,
    required this.total,
    required this.statisticsDate,
  });

  factory AttendanceStatistics.empty() => AttendanceStatistics(
        firstSemester: const {},
        secondSemester: const {},
        total: AttendanceTotals.empty(),
        statisticsDate: '',
      );

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) {
    return AttendanceStatistics(
      firstSemester: JsonUtils.readStringMap(json, [
        'firstSemester',
        'first_semester',
        'first',
      ]),
      secondSemester: JsonUtils.readStringMap(json, [
        'secondSemester',
        'second_semester',
        'second',
      ]),
      total: AttendanceTotals.fromJson(
        (json['total'] ?? json['overall'] ?? json['totals'] ?? {}) as Map,
      ),
      statisticsDate: JsonUtils.readString(json, [
        'statisticsDate',
        'updated_at',
        'generated_at',
        'date',
      ]),
    );
  }
}

class AttendanceTotals {
  final int truancy;
  final int personalLeave;
  final int sickLeave;
  final int officialLeave;

  AttendanceTotals({
    required this.truancy,
    required this.personalLeave,
    required this.sickLeave,
    required this.officialLeave,
  });

  factory AttendanceTotals.empty() => AttendanceTotals(
        truancy: 0,
        personalLeave: 0,
        sickLeave: 0,
        officialLeave: 0,
      );

  factory AttendanceTotals.fromJson(Map<dynamic, dynamic> json) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    return AttendanceTotals(
      truancy: JsonUtils.readInt(map, ['truancy', 'truant', 'absence']),
      personalLeave:
          JsonUtils.readInt(map, ['personalLeave', 'personal_leave']),
      sickLeave: JsonUtils.readInt(map, ['sickLeave', 'sick_leave']),
      officialLeave: JsonUtils.readInt(map, [
        'officialLeave',
        'official_leave',
        'public_leave',
      ]),
    );
  }
}

class CourseSchedule {
  final String id;
  final String weekday;
  final String period;

  CourseSchedule({required this.weekday, required this.period})
      : id = '$weekday-$period';

  factory CourseSchedule.fromJson(Map<String, dynamic> json) {
    return CourseSchedule(
      weekday: JsonUtils.readString(json, [
        'weekday',
        'day',
        'week',
        'week_day',
      ]),
      period: JsonUtils.readString(json, [
        'period',
        'section',
        'class_period',
      ]),
    );
  }
}

class CourseInfo {
  final int count;
  final List<CourseSchedule> schedule;

  CourseInfo({required this.count, required this.schedule});

  factory CourseInfo.fromJson(Map<String, dynamic> json) {
    final count = JsonUtils.readInt(json, ['count', 'credits', 'periods']);
    final scheduleValue = json['schedule'] ??
        json['schedules'] ??
        json['timetable'] ??
        json['schedule'];

    List<CourseSchedule> schedule = [];
    if (scheduleValue is List) {
      schedule = scheduleValue
          .whereType<Map>()
          .map((e) => CourseSchedule.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (scheduleValue is Map) {
      schedule = [CourseSchedule.fromJson(scheduleValue.cast<String, dynamic>())];
    }

    return CourseInfo(count: count, schedule: schedule);
  }
}

class SubjectGrade {
  final String id;
  final String subject;
  final SemesterGrade firstSemester;
  final SemesterGrade secondSemester;
  final String yearGrade;

  SubjectGrade({
    required this.subject,
    required this.firstSemester,
    required this.secondSemester,
    required this.yearGrade,
  }) : id = subject;

  factory SubjectGrade.fromJson(Map<String, dynamic> json) {
    return SubjectGrade(
      subject: json['subject']?.toString() ?? '',
      firstSemester: SemesterGrade.fromJson(
        (json['first_semester'] ?? json['firstSemester'] ?? {}) as Map,
      ),
      secondSemester: SemesterGrade.fromJson(
        (json['second_semester'] ?? json['secondSemester'] ?? {}) as Map,
      ),
      yearGrade: JsonUtils.readString(json, ['year_grade', 'annual_score']),
    );
  }
}

class SemesterGrade {
  final String attribute;
  final String credit;
  final String score;

  SemesterGrade({
    required this.attribute,
    required this.credit,
    required this.score,
  });

  factory SemesterGrade.empty() => SemesterGrade(attribute: '', credit: '', score: '');

  factory SemesterGrade.fromJson(Map<dynamic, dynamic> json) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    return SemesterGrade(
      attribute: JsonUtils.readString(map, ['attribute', 'type']),
      credit: JsonUtils.readString(map, ['credit', 'credits']),
      score: JsonUtils.readString(map, ['score']),
    );
  }
}

class TotalScore {
  final String firstSemester;
  final String secondSemester;
  final String year;

  TotalScore({
    required this.firstSemester,
    required this.secondSemester,
    required this.year,
  });

  factory TotalScore.fromJson(Map<dynamic, dynamic> json) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    return TotalScore(
      firstSemester: JsonUtils.readString(map, ['first_semester', 'firstSemester']),
      secondSemester: JsonUtils.readString(map, ['second_semester', 'secondSemester']),
      year: JsonUtils.readString(map, ['year', 'annual']),
    );
  }
}

class DailyPerformance {
  final String evaluation;
  final String description;
  final String serviceHours;
  final String specialPerformance;
  final String suggestions;
  final String others;

  DailyPerformance({
    required this.evaluation,
    required this.description,
    required this.serviceHours,
    required this.specialPerformance,
    required this.suggestions,
    required this.others,
  });

  bool get isCompletelyEmpty =>
      evaluation.isEmpty &&
      description.isEmpty &&
      serviceHours.isEmpty &&
      specialPerformance.isEmpty &&
      suggestions.isEmpty &&
      others.isEmpty;

  factory DailyPerformance.empty() => DailyPerformance(
        evaluation: '',
        description: '',
        serviceHours: '',
        specialPerformance: '',
        suggestions: '',
        others: '',
      );

  factory DailyPerformance.fromJson(Map<String, dynamic> json) {
    final dailyLife = json['daily_life_performance'];
    Map<String, dynamic> dailyLifeMap = {};
    if (dailyLife is Map) {
      dailyLifeMap = dailyLife.cast<String, dynamic>();
    }

    return DailyPerformance(
      evaluation: JsonUtils.readString(json, ['evaluation'])
          .ifEmpty(JsonUtils.readString(dailyLifeMap, ['evaluation'])),
      description: JsonUtils.readString(json, ['description'])
          .ifEmpty(JsonUtils.readString(dailyLifeMap, ['description']))
          .ifEmpty(JsonUtils.readString(json, ['comment'])),
      serviceHours: JsonUtils.readString(json, [
        'serviceHours',
        'service_hours',
        'service',
        'service_learning',
      ]),
      specialPerformance: JsonUtils.readString(json, [
        'specialPerformance',
        'special_performance',
        'special',
        'special_achievements',
      ]),
      suggestions: JsonUtils.readString(json, [
        'suggestions',
        'suggestion',
        'suggestions_and_comments',
      ]),
      others: JsonUtils.readString(json, ['others', 'remarks']),
    );
  }
}

extension _StringUtils on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class GradeData {
  final String studentInfo;
  final List<SubjectGrade> subjects;
  final Map<String, TotalScore> totalScores;
  final Map<String, DailyPerformance> dailyPerformance;

  GradeData({
    required this.studentInfo,
    required this.subjects,
    required this.totalScores,
    required this.dailyPerformance,
  });

  factory GradeData.empty() => GradeData(
        studentInfo: '',
        subjects: const [],
        totalScores: const {},
        dailyPerformance: const {},
      );

  factory GradeData.fromJson(Map<String, dynamic> json) {
    final subjectsRaw = json['subjects'] ?? json['subject_scores'] ?? [];
    final totalRaw = json['total_scores'] ?? {};
    final dailyRaw = json['daily_performance'] ?? {};

    return GradeData(
      studentInfo: json['student_info']?.toString() ?? '',
      subjects: (subjectsRaw is List)
          ? subjectsRaw
              .whereType<Map>()
              .map((e) => SubjectGrade.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      totalScores: (totalRaw is Map)
          ? totalRaw.map((key, value) => MapEntry(
                key.toString(),
                TotalScore.fromJson((value as Map).cast<String, dynamic>()),
              ))
          : {},
      dailyPerformance: (dailyRaw is Map)
          ? dailyRaw.map((key, value) => MapEntry(
                key.toString(),
                DailyPerformance.fromJson((value as Map).cast<String, dynamic>()),
              ))
          : {},
    );
  }
}

class ExamMenuItem {
  final String id;
  final String name;
  final String url;
  final String fullUrl;

  ExamMenuItem({
    required this.name,
    required this.url,
    required this.fullUrl,
  }) : id = '$name-$url';

  factory ExamMenuItem.fromJson(Map<String, dynamic> json, {String fullUrl = ''}) {
    return ExamMenuItem(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      fullUrl: fullUrl,
    );
  }
}

class ExamSubjectScore {
  final String id;
  final String subject;
  final String personalScore;
  final String classAverage;

  ExamSubjectScore({
    required this.subject,
    required this.personalScore,
    required this.classAverage,
  }) : id = subject;

  factory ExamSubjectScore.fromJson(Map<String, dynamic> json) {
    return ExamSubjectScore(
      subject: JsonUtils.readString(json, ['subject', 'name']),
      personalScore: JsonUtils.readString(json, [
        'personalScore',
        'score',
        'student_score',
        'personal_score',
      ]),
      classAverage: JsonUtils.readString(json, [
        'classAverage',
        'avg',
        'class_avg',
        'class_average',
      ]),
    );
  }
}

class ExamSummary {
  final String totalScore;
  final String averageScore;
  final String classRank;
  final String departmentRank;

  ExamSummary({
    required this.totalScore,
    required this.averageScore,
    required this.classRank,
    required this.departmentRank,
  });

  factory ExamSummary.empty() => ExamSummary(
        totalScore: '',
        averageScore: '',
        classRank: '',
        departmentRank: '',
      );

  factory ExamSummary.fromJson(Map<String, dynamic> json) {
    return ExamSummary(
      totalScore: JsonUtils.readString(json, ['totalScore', 'total']),
      averageScore: JsonUtils.readString(json, ['averageScore', 'average']),
      classRank: JsonUtils.readString(json, ['classRank', 'class_rank', 'rank']),
      departmentRank:
          JsonUtils.readString(json, ['departmentRank', 'department_rank']),
    );
  }
}

class StudentInfo {
  final String studentId;
  final String name;
  final String className;

  StudentInfo({
    required this.studentId,
    required this.name,
    required this.className,
  });

  factory StudentInfo.empty() => StudentInfo(studentId: '', name: '', className: '');

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      studentId: JsonUtils.readString(json, [
        'studentId',
        'student_id',
        'student_no',
        'id',
      ]),
      name: JsonUtils.readString(json, ['name', 'full_name']),
      className: JsonUtils.readString(json, [
        'className',
        'class_name',
        'class_no',
        'homeroom',
      ]),
    );
  }
}

class ExamScoreData {
  StudentInfo studentInfo;
  String examInfo;
  List<ExamSubjectScore> subjects;
  ExamSummary summary;

  ExamScoreData({
    required this.studentInfo,
    required this.examInfo,
    required this.subjects,
    required this.summary,
  });

  factory ExamScoreData.empty() => ExamScoreData(
        studentInfo: StudentInfo.empty(),
        examInfo: '',
        subjects: [],
        summary: ExamSummary.empty(),
      );
}

class SemesterInfo {
  final String schoolYear;
  final String semester;

  SemesterInfo({required this.schoolYear, required this.semester});
}

class CourseExtra {
  String room;
  String teacher;

  CourseExtra({this.room = '', this.teacher = ''});

  Map<String, dynamic> toJson() => {'room': room, 'teacher': teacher};

  factory CourseExtra.fromJson(Map<String, dynamic> json) => CourseExtra(
        room: json['room']?.toString() ?? '',
        teacher: json['teacher']?.toString() ?? '',
      );
}

class PeriodTime {
  final String startTime;
  final String endTime;

  PeriodTime({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() => {'startTime': startTime, 'endTime': endTime};

  factory PeriodTime.fromMap(Map<String, dynamic> json) => PeriodTime(
        startTime: json['startTime']?.toString() ?? '',
        endTime: json['endTime']?.toString() ?? '',
      );
}

class TimetableEntry {
  final String id;
  final String weekday;
  final String period;
  final String subject;

  TimetableEntry({
    required this.weekday,
    required this.period,
    required this.subject,
  }) : id = '$weekday-$period-$subject';

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      weekday: JsonUtils.readString(json, ['weekday', 'day', 'week_day']),
      period: JsonUtils.readString(json, ['period', 'section', 'class_period']),
      subject: JsonUtils.readString(json, ['subject', 'course', 'course_name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'period': period,
        'subject': subject,
      };
}

class TimetableData {
  final List<TimetableEntry> entries;
  final Map<String, PeriodTime> periodTimes;
  final Map<String, CourseInfo> curriculum;

  TimetableData({
    required this.entries,
    required this.periodTimes,
    required this.curriculum,
  });

  factory TimetableData.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'] ?? json['timetable'] ?? [];
    final periodRaw = json['periodTimes'] ?? json['periods'] ?? {};
    final curriculumRaw = json['curriculum'] ?? json['classes'] ?? {};

    return TimetableData(
      entries: (entriesRaw is List)
          ? entriesRaw
              .whereType<Map>()
              .map((e) => TimetableEntry.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      periodTimes: (periodRaw is Map)
          ? periodRaw.map((key, value) => MapEntry(
                key.toString(),
                PeriodTime(
                  startTime: (value as Map)['startTime']?.toString() ??
                      (value)['start_time']?.toString() ??
                      '',
                  endTime: (value)['endTime']?.toString() ??
                      (value)['end_time']?.toString() ??
                      '',
                ),
              ))
          : {},
      curriculum: (curriculumRaw is Map)
          ? curriculumRaw.map((key, value) => MapEntry(
                key.toString(),
                CourseInfo.fromJson((value as Map).cast<String, dynamic>()),
              ))
          : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'periodTimes': periodTimes.map((key, value) => MapEntry(key, {
              'startTime': value.startTime,
              'endTime': value.endTime,
            })),
        'curriculum': curriculum.map((key, value) => MapEntry(key, {
              'count': value.count,
              'schedule': value.schedule
                  .map((e) => {'weekday': e.weekday, 'period': e.period})
                  .toList(),
            })),
      };

  String toJsonString() => jsonEncode(toJson());

  static TimetableData? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TimetableData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

class SubjectAbsence {
  final String id;
  final String subject;
  final int truancy;
  final int personalLeave;
  final int total;
  final int totalClasses;
  final int percentage;

  SubjectAbsence({
    required this.subject,
    required this.truancy,
    required this.personalLeave,
    required this.total,
    required this.totalClasses,
    required this.percentage,
  }) : id = subject;

  factory SubjectAbsence.fromJson(Map<String, dynamic> json) {
    final truancy = JsonUtils.readInt(json, ['truancy', 'truant']);
    final personal = JsonUtils.readInt(json, ['personalLeave', 'personal_leave']);
    final total = JsonUtils.readInt(json, ['total', 'sum'], defaultValue: truancy + personal);
    final totalClasses = JsonUtils.readInt(json, ['totalClasses', 'total_classes']);
    final percentage = JsonUtils.readInt(json, ['percentage', 'rate'],
        defaultValue: totalClasses > 0 ? ((total / totalClasses) * 100).round() : 0);
    return SubjectAbsence(
      subject: JsonUtils.readString(json, ['subject', 'course', 'name']),
      truancy: truancy,
      personalLeave: personal,
      total: total,
      totalClasses: totalClasses,
      percentage: percentage,
    );
  }
}

class NoticeItem {
  final String link;
  final String title;
  final String publisher;
  final String date;
  final String views;

  NoticeItem({
    required this.link,
    required this.title,
    required this.publisher,
    required this.date,
    required this.views,
  });

  factory NoticeItem.fromJson(Map<String, dynamic> json) {
    return NoticeItem(
      link: JsonUtils.readString(json, ['link', 'url', 'href']),
      title: JsonUtils.readString(json, ['title', 'subject']),
      publisher: JsonUtils.readString(json, ['publisher', 'author', 'department']),
      date: JsonUtils.readString(json, ['date', 'publish_date', 'created_at']),
      views: JsonUtils.readString(json, ['views', 'view_count', 'hits'],
          defaultValue: JsonUtils.readInt(json, ['views', 'view_count', 'hits']).toString()),
    );
  }
}

class VocPassUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatar;
  final bool emailVisibility;
  final bool verified;
  final bool? shareStatus;

  VocPassUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.avatar,
    required this.emailVisibility,
    required this.verified,
    required this.shareStatus,
  });

  String? get avatarURL => (avatar != null && avatar!.isNotEmpty) ? avatar : null;
  String get displayName => name.isEmpty ? username : name;

  factory VocPassUser.fromJson(Map<String, dynamic> json) {
    return VocPassUser(
      id: JsonUtils.readString(json, ['id']),
      name: JsonUtils.readString(json, ['name']),
      username: JsonUtils.readString(json, ['username']),
      email: JsonUtils.readString(json, ['email']),
      avatar: json['avatar']?.toString(),
      emailVisibility: JsonUtils.readBool(json, ['email_visibility', 'emailVisibility']),
      verified: JsonUtils.readBool(json, ['verified']),
      shareStatus: json.containsKey('share_status') || json.containsKey('shareStatus')
          ? JsonUtils.readBool(json, ['share_status', 'shareStatus'])
          : null,
    );
  }
}

class VocPassPublicUser {
  final String id;
  final String name;
  final String username;
  final String? avatar;

  VocPassPublicUser({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
  });

  String? get avatarURL => (avatar != null && avatar!.isNotEmpty) ? avatar : null;
  String get displayName => name.isEmpty ? username : name;

  factory VocPassPublicUser.fromJson(Map<String, dynamic> json) {
    return VocPassPublicUser(
      id: JsonUtils.readString(json, ['id']),
      name: JsonUtils.readString(json, ['name']),
      username: JsonUtils.readString(json, ['username']),
      avatar: json['avatar']?.toString(),
    );
  }
}

// MARK: - 餐廳

class RestaurantMap {
  final double lon;
  final double lat;

  RestaurantMap({required this.lon, required this.lat});

  factory RestaurantMap.fromJson(Map<String, dynamic> json) => RestaurantMap(
        lon: (json['lon'] as num?)?.toDouble() ?? 0,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
      );
}

class Restaurant {
  final String id;
  final String name;
  final String school;
  final String icon;
  final RestaurantMap? map;
  final String? user;
  final String? address;

  Restaurant({
    required this.id,
    required this.name,
    required this.school,
    required this.icon,
    this.map,
    this.user,
    this.address,
  });

  String? get iconURL => icon.isNotEmpty ? icon : null;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: JsonUtils.readString(json, ['id']),
      name: JsonUtils.readString(json, ['name']),
      school: JsonUtils.readString(json, ['school']),
      icon: JsonUtils.readString(json, ['icon']),
      map: json['map'] is Map
          ? RestaurantMap.fromJson((json['map'] as Map).cast<String, dynamic>())
          : null,
      user: json['user']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class RestaurantEvaluation {
  final String id;
  final String title;
  final String description;
  final int score;
  final String user;

  RestaurantEvaluation({
    required this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.user,
  });

  String get plainDescription => description
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  factory RestaurantEvaluation.fromJson(Map<String, dynamic> json) {
    return RestaurantEvaluation(
      id: JsonUtils.readString(json, ['id']),
      title: JsonUtils.readString(json, ['title']),
      description: JsonUtils.readString(json, ['description']),
      score: JsonUtils.readInt(json, ['score']),
      user: JsonUtils.readString(json, ['user']),
    );
  }
}

class RestaurantMenu {
  final String id;
  final String menu;
  final String restaurant;
  final String user;

  RestaurantMenu({
    required this.id,
    required this.menu,
    required this.restaurant,
    required this.user,
  });

  String? get menuURL => menu.isNotEmpty ? menu : null;

  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    return RestaurantMenu(
      id: JsonUtils.readString(json, ['id']),
      menu: JsonUtils.readString(json, ['menu']),
      restaurant: JsonUtils.readString(json, ['restaurant']),
      user: JsonUtils.readString(json, ['uesr', 'user']),
    );
  }
}
