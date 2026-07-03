import 'package:flutter_test/flutter_test.dart';
import 'package:VosPass/models/models.dart';

void main() {
  group('JsonUtils', () {
    group('readString', () {
      test('returns value for first matching key', () {
        final json = {'name': 'Alice', 'full_name': 'Alice B.'};
        expect(JsonUtils.readString(json, ['name']), 'Alice');
      });

      test('falls back to next key when first is missing', () {
        final json = {'full_name': 'Alice B.'};
        expect(JsonUtils.readString(json, ['name', 'full_name']), 'Alice B.');
      });

      test('returns defaultValue when no key matches', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readString(json, ['name'], defaultValue: 'N/A'), 'N/A');
      });

      test('converts num to string', () {
        final json = {'score': 95};
        expect(JsonUtils.readString(json, ['score']), '95');
      });

      test('converts bool to string', () {
        final json = {'active': true};
        expect(JsonUtils.readString(json, ['active']), 'true');
      });

      test('skips null values', () {
        final json = <String, dynamic>{'name': null, 'fallback': 'ok'};
        expect(JsonUtils.readString(json, ['name', 'fallback']), 'ok');
      });
    });

    group('readStringNullable', () {
      test('returns null for empty string result', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readStringNullable(json, ['x']), isNull);
      });

      test('returns value when present', () {
        final json = {'x': 'hello'};
        expect(JsonUtils.readStringNullable(json, ['x']), 'hello');
      });
    });

    group('readInt', () {
      test('reads int value', () {
        final json = {'count': 42};
        expect(JsonUtils.readInt(json, ['count']), 42);
      });

      test('converts double to int', () {
        final json = {'count': 3.7};
        expect(JsonUtils.readInt(json, ['count']), 3);
      });

      test('parses string to int', () {
        final json = {'count': '  10  '};
        expect(JsonUtils.readInt(json, ['count']), 10);
      });

      test('converts bool to int', () {
        final json = {'flag': true};
        expect(JsonUtils.readInt(json, ['flag']), 1);
        final json2 = {'flag': false};
        expect(JsonUtils.readInt(json2, ['flag']), 0);
      });

      test('returns defaultValue when no key matches', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readInt(json, ['count'], defaultValue: -1), -1);
      });

      test('returns defaultValue for unparseable string', () {
        final json = {'count': 'abc'};
        expect(JsonUtils.readInt(json, ['count'], defaultValue: 5), 5);
      });
    });

    group('readBool', () {
      test('reads bool value directly', () {
        final json = {'active': true};
        expect(JsonUtils.readBool(json, ['active']), true);
      });

      test('converts int to bool', () {
        final json = {'active': 1};
        expect(JsonUtils.readBool(json, ['active']), true);
        final json2 = {'active': 0};
        expect(JsonUtils.readBool(json2, ['active']), false);
      });

      test('parses truthy strings', () {
        for (final v in ['true', '1', 'yes', 'y', 'ok', 'success']) {
          final json = {'val': v};
          expect(JsonUtils.readBool(json, ['val']), true, reason: 'Expected $v to be true');
        }
      });

      test('parses falsy strings', () {
        for (final v in ['false', '0', 'no', 'n', 'random']) {
          final json = {'val': v};
          expect(JsonUtils.readBool(json, ['val']), false, reason: 'Expected $v to be false');
        }
      });

      test('is case insensitive', () {
        final json = {'val': ' TRUE '};
        expect(JsonUtils.readBool(json, ['val']), true);
      });

      test('returns defaultValue when no key matches', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readBool(json, ['active'], defaultValue: true), true);
      });
    });

    group('readStringList', () {
      test('reads list of strings', () {
        final json = {
          'tags': ['a', 'b', 'c']
        };
        expect(JsonUtils.readStringList(json, ['tags']), ['a', 'b', 'c']);
      });

      test('filters empty entries and trims', () {
        final json = {
          'tags': [' hello ', '', '  ', 'world']
        };
        expect(JsonUtils.readStringList(json, ['tags']), ['hello', 'world']);
      });

      test('parses comma-separated string', () {
        final json = {'tags': 'a, b, c'};
        expect(JsonUtils.readStringList(json, ['tags']), ['a', 'b', 'c']);
      });

      test('returns default when no key matches', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readStringList(json, ['tags']), isEmpty);
      });
    });

    group('readStringMap', () {
      test('reads map and converts values to string', () {
        final json = {
          'data': {'a': 1, 'b': 'hello'}
        };
        expect(
          JsonUtils.readStringMap(json, ['data']),
          {'a': '1', 'b': 'hello'},
        );
      });

      test('returns default when no key matches', () {
        final json = <String, dynamic>{};
        expect(JsonUtils.readStringMap(json, ['data']), isEmpty);
      });
    });
  });

  group('ApiResponse', () {
    test('parses standard response with code, message, data', () {
      final json = {
        'code': 200,
        'message': 'OK',
        'data': {'key': 'value'},
      };
      final response = ApiResponse.fromJson(json, (d) => d);
      expect(response.code, 200);
      expect(response.message, 'OK');
      expect(response.data, {'key': 'value'});
    });

    test('resolves alternative keys (status, msg, result)', () {
      final json = {
        'status': 404,
        'msg': 'Not Found',
        'result': 'some data',
      };
      final response = ApiResponse.fromJson(json, (d) => d.toString());
      expect(response.code, 404);
      expect(response.message, 'Not Found');
      expect(response.data, 'some data');
    });

    test('resolves success boolean field', () {
      final json = {
        'success': false,
        'detail': 'fail reason',
        'payload': 123,
      };
      final response = ApiResponse.fromJson(json, (d) => d as int);
      expect(response.code, 0);
      expect(response.message, 'fail reason');
      expect(response.data, 123);
    });

    test('handles non-map json input', () {
      final response = ApiResponse.fromJson('raw string', (d) => d.toString());
      expect(response.code, 200);
      expect(response.data, 'raw string');
    });

    test('falls back to the entire map as data when no data/result/payload key', () {
      final json = {'code': 200, 'message': 'ok', 'name': 'test'};
      final response = ApiResponse.fromJson(json, (d) => d);
      expect((response.data as Map)['name'], 'test');
    });
  });

  group('MeritDemeritRecord', () {
    test('fromJson parses all fields', () {
      final json = {
        'date_occurred': '2024-01-15',
        'date_approved': '2024-01-20',
        'reason': 'Good behavior',
        'action': '小功',
        'date_revoked': '2024-02-01',
        'year': '112',
      };
      final record = MeritDemeritRecord.fromJson(json);
      expect(record.dateOccurred, '2024-01-15');
      expect(record.dateApproved, '2024-01-20');
      expect(record.reason, 'Good behavior');
      expect(record.action, '小功');
      expect(record.dateRevoked, '2024-02-01');
      expect(record.year, '112');
      expect(record.id, '2024-01-15-小功-Good behavior-2024-01-20');
    });

    test('fromJson with alternative keys', () {
      final json = {
        'dateOccurred': '2024-03-01',
        'dateApproved': '2024-03-05',
        'reason': 'test',
        'content': '嘉獎',
        'school_year': '113',
      };
      final record = MeritDemeritRecord.fromJson(json);
      expect(record.dateOccurred, '2024-03-01');
      expect(record.action, '嘉獎');
      expect(record.year, '113');
      expect(record.dateRevoked, isNull);
    });
  });

  group('AbsenceRecord', () {
    test('fromJson parses all fields', () {
      final json = {
        'academic_term': '112-1',
        'date': '2024-03-15',
        'weekday': '五',
        'period': '3',
        'cell': '曠課',
      };
      final record = AbsenceRecord.fromJson(json);
      expect(record.academicYear, '112-1');
      expect(record.date, '2024-03-15');
      expect(record.weekday, '五');
      expect(record.period, '3');
      expect(record.status, '曠課');
      expect(record.id, '2024-03-15-五-3-曠課');
    });

    test('fromJson with alternative keys', () {
      final json = {
        'semester': '112-2',
        'date_occurred': '2024-05-01',
        'day': '一',
        'section': '1',
        'attendance_type': '事假',
      };
      final record = AbsenceRecord.fromJson(json);
      expect(record.academicYear, '112-2');
      expect(record.weekday, '一');
      expect(record.period, '1');
      expect(record.status, '事假');
    });
  });

  group('AttendanceTotals', () {
    test('fromJson parses all fields', () {
      final json = {'truancy': 3, 'personalLeave': 5, 'sickLeave': 2, 'officialLeave': 1};
      final totals = AttendanceTotals.fromJson(json);
      expect(totals.truancy, 3);
      expect(totals.personalLeave, 5);
      expect(totals.sickLeave, 2);
      expect(totals.officialLeave, 1);
    });

    test('empty factory creates zero values', () {
      final totals = AttendanceTotals.empty();
      expect(totals.truancy, 0);
      expect(totals.personalLeave, 0);
      expect(totals.sickLeave, 0);
      expect(totals.officialLeave, 0);
    });

    test('fromJson with alternative keys', () {
      final json = {'truant': 2, 'personal_leave': 4, 'sick_leave': 1, 'public_leave': 3};
      final totals = AttendanceTotals.fromJson(json);
      expect(totals.truancy, 2);
      expect(totals.personalLeave, 4);
      expect(totals.sickLeave, 1);
      expect(totals.officialLeave, 3);
    });
  });

  group('AttendanceStatistics', () {
    test('fromJson parses all fields', () {
      final json = {
        'firstSemester': {'曠課': '3', '事假': '2'},
        'secondSemester': {'曠課': '1'},
        'total': {'truancy': 4, 'personalLeave': 2, 'sickLeave': 0, 'officialLeave': 0},
        'statisticsDate': '2024-06-01',
      };
      final stats = AttendanceStatistics.fromJson(json);
      expect(stats.firstSemester['曠課'], '3');
      expect(stats.secondSemester['曠課'], '1');
      expect(stats.total.truancy, 4);
      expect(stats.statisticsDate, '2024-06-01');
    });

    test('empty factory', () {
      final stats = AttendanceStatistics.empty();
      expect(stats.firstSemester, isEmpty);
      expect(stats.secondSemester, isEmpty);
      expect(stats.statisticsDate, '');
    });
  });

  group('CourseSchedule', () {
    test('fromJson parses fields', () {
      final json = {'weekday': '一', 'period': '1'};
      final cs = CourseSchedule.fromJson(json);
      expect(cs.weekday, '一');
      expect(cs.period, '1');
      expect(cs.id, '一-1');
    });

    test('fromJson with alternative keys', () {
      final json = {'day': '三', 'section': '5'};
      final cs = CourseSchedule.fromJson(json);
      expect(cs.weekday, '三');
      expect(cs.period, '5');
    });
  });

  group('CourseInfo', () {
    test('fromJson parses schedule list', () {
      final json = {
        'count': 3,
        'schedule': [
          {'weekday': '一', 'period': '1'},
          {'weekday': '一', 'period': '2'},
        ],
      };
      final info = CourseInfo.fromJson(json);
      expect(info.count, 3);
      expect(info.schedule.length, 2);
      expect(info.schedule[0].weekday, '一');
    });

    test('fromJson handles single schedule as map', () {
      final json = {
        'credits': 2,
        'schedule': {'day': '五', 'section': '3'},
      };
      final info = CourseInfo.fromJson(json);
      expect(info.count, 2);
      expect(info.schedule.length, 1);
      expect(info.schedule[0].weekday, '五');
    });

    test('fromJson handles missing schedule', () {
      final json = {'count': 1};
      final info = CourseInfo.fromJson(json);
      expect(info.schedule, isEmpty);
    });
  });

  group('SemesterGrade', () {
    test('fromJson parses fields', () {
      final json = {'attribute': '必修', 'credit': '3', 'score': '85'};
      final grade = SemesterGrade.fromJson(json);
      expect(grade.attribute, '必修');
      expect(grade.credit, '3');
      expect(grade.score, '85');
    });

    test('empty factory', () {
      final grade = SemesterGrade.empty();
      expect(grade.attribute, '');
      expect(grade.credit, '');
      expect(grade.score, '');
    });
  });

  group('SubjectGrade', () {
    test('fromJson parses with nested semesters', () {
      final json = {
        'subject': '國文',
        'first_semester': {'attribute': '必修', 'credit': '4', 'score': '90'},
        'second_semester': {'attribute': '必修', 'credit': '4', 'score': '85'},
        'year_grade': '88',
      };
      final grade = SubjectGrade.fromJson(json);
      expect(grade.subject, '國文');
      expect(grade.firstSemester.score, '90');
      expect(grade.secondSemester.score, '85');
      expect(grade.yearGrade, '88');
      expect(grade.id, '國文');
    });
  });

  group('TotalScore', () {
    test('fromJson parses fields', () {
      final json = {
        'first_semester': '82',
        'second_semester': '78',
        'year': '80',
      };
      final score = TotalScore.fromJson(json);
      expect(score.firstSemester, '82');
      expect(score.secondSemester, '78');
      expect(score.year, '80');
    });
  });

  group('DailyPerformance', () {
    test('fromJson parses fields', () {
      final json = {
        'evaluation': 'Good',
        'description': 'Nice student',
        'serviceHours': '10',
        'specialPerformance': 'Leader',
        'suggestions': 'Keep going',
        'others': 'None',
      };
      final dp = DailyPerformance.fromJson(json);
      expect(dp.evaluation, 'Good');
      expect(dp.description, 'Nice student');
      expect(dp.serviceHours, '10');
      expect(dp.specialPerformance, 'Leader');
      expect(dp.suggestions, 'Keep going');
      expect(dp.others, 'None');
    });

    test('isCompletelyEmpty returns true when all empty', () {
      final dp = DailyPerformance.empty();
      expect(dp.isCompletelyEmpty, true);
    });

    test('isCompletelyEmpty returns false when any field has value', () {
      final dp = DailyPerformance(
        evaluation: 'A',
        description: '',
        serviceHours: '',
        specialPerformance: '',
        suggestions: '',
        others: '',
      );
      expect(dp.isCompletelyEmpty, false);
    });

    test('fromJson reads from daily_life_performance nested map', () {
      final json = {
        'daily_life_performance': {
          'evaluation': 'Nested eval',
          'description': 'Nested desc',
        },
        'serviceHours': '5',
        'specialPerformance': '',
        'suggestions': '',
        'others': '',
      };
      final dp = DailyPerformance.fromJson(json);
      expect(dp.evaluation, 'Nested eval');
      expect(dp.description, 'Nested desc');
      expect(dp.serviceHours, '5');
    });
  });

  group('GradeData', () {
    test('fromJson parses complete data', () {
      final json = {
        'student_info': 'Class A - Student 1',
        'subjects': [
          {
            'subject': '數學',
            'first_semester': {'attribute': '必修', 'credit': '4', 'score': '92'},
            'second_semester': {'attribute': '必修', 'credit': '4', 'score': '88'},
            'year_grade': '90',
          },
        ],
        'total_scores': {
          '加權': {
            'first_semester': '85',
            'second_semester': '82',
            'year': '84',
          },
        },
        'daily_performance': {
          '113-1': {
            'evaluation': 'A',
            'description': '',
            'serviceHours': '10',
            'specialPerformance': '',
            'suggestions': '',
            'others': '',
          },
        },
      };
      final data = GradeData.fromJson(json);
      expect(data.studentInfo, 'Class A - Student 1');
      expect(data.subjects.length, 1);
      expect(data.subjects[0].subject, '數學');
      expect(data.totalScores['加權']!.firstSemester, '85');
      expect(data.dailyPerformance['113-1']!.evaluation, 'A');
    });

    test('empty factory', () {
      final data = GradeData.empty();
      expect(data.studentInfo, '');
      expect(data.subjects, isEmpty);
      expect(data.totalScores, isEmpty);
      expect(data.dailyPerformance, isEmpty);
    });
  });

  group('ExamMenuItem', () {
    test('fromJson parses fields', () {
      final json = {'name': 'Midterm', 'url': '/exam/1'};
      final item = ExamMenuItem.fromJson(json, fullUrl: 'https://school.tw/exam/1');
      expect(item.name, 'Midterm');
      expect(item.url, '/exam/1');
      expect(item.fullUrl, 'https://school.tw/exam/1');
      expect(item.id, 'Midterm-/exam/1');
    });
  });

  group('ExamSubjectScore', () {
    test('fromJson parses fields', () {
      final json = {'subject': '英文', 'personalScore': '90', 'classAverage': '75'};
      final score = ExamSubjectScore.fromJson(json);
      expect(score.subject, '英文');
      expect(score.personalScore, '90');
      expect(score.classAverage, '75');
      expect(score.id, '英文');
    });

    test('fromJson with alternative keys', () {
      final json = {'name': '國文', 'score': '88', 'class_avg': '70'};
      final score = ExamSubjectScore.fromJson(json);
      expect(score.subject, '國文');
      expect(score.personalScore, '88');
      expect(score.classAverage, '70');
    });
  });

  group('ExamSummary', () {
    test('fromJson parses all fields', () {
      final json = {
        'totalScore': '450',
        'averageScore': '90',
        'classRank': '5',
        'departmentRank': '10',
      };
      final summary = ExamSummary.fromJson(json);
      expect(summary.totalScore, '450');
      expect(summary.averageScore, '90');
      expect(summary.classRank, '5');
      expect(summary.departmentRank, '10');
    });

    test('empty factory', () {
      final summary = ExamSummary.empty();
      expect(summary.totalScore, '');
      expect(summary.classRank, '');
    });
  });

  group('StudentInfo', () {
    test('fromJson parses all fields', () {
      final json = {'studentId': 'S001', 'name': 'Alice', 'className': 'ClassA'};
      final info = StudentInfo.fromJson(json);
      expect(info.studentId, 'S001');
      expect(info.name, 'Alice');
      expect(info.className, 'ClassA');
    });

    test('fromJson with alternative keys', () {
      final json = {'student_no': 'S002', 'full_name': 'Bob', 'homeroom': 'ClassB'};
      final info = StudentInfo.fromJson(json);
      expect(info.studentId, 'S002');
      expect(info.name, 'Bob');
      expect(info.className, 'ClassB');
    });

    test('empty factory', () {
      final info = StudentInfo.empty();
      expect(info.studentId, '');
      expect(info.name, '');
      expect(info.className, '');
    });
  });

  group('TimetableEntry', () {
    test('fromJson and toJson roundtrip', () {
      final json = {'weekday': '二', 'period': '4', 'subject': '物理'};
      final entry = TimetableEntry.fromJson(json);
      expect(entry.weekday, '二');
      expect(entry.period, '4');
      expect(entry.subject, '物理');
      expect(entry.id, '二-4-物理');
      final output = entry.toJson();
      expect(output['weekday'], '二');
      expect(output['period'], '4');
      expect(output['subject'], '物理');
    });
  });

  group('TimetableData', () {
    test('fromJson parses entries, periodTimes, and curriculum', () {
      final json = {
        'entries': [
          {'weekday': '一', 'period': '1', 'subject': '國文'},
          {'weekday': '一', 'period': '2', 'subject': '數學'},
        ],
        'periodTimes': {
          '1': {'startTime': '08:10', 'endTime': '09:00'},
          '2': {'startTime': '09:10', 'endTime': '10:00'},
        },
        'curriculum': {
          '國文': {
            'count': 4,
            'schedule': [
              {'weekday': '一', 'period': '1'},
            ],
          },
        },
      };
      final data = TimetableData.fromJson(json);
      expect(data.entries.length, 2);
      expect(data.entries[0].subject, '國文');
      expect(data.periodTimes['1']!.startTime, '08:10');
      expect(data.curriculum['國文']!.count, 4);
    });

    test('toJson and fromJsonString roundtrip', () {
      final data = TimetableData(
        entries: [
          TimetableEntry(weekday: '一', period: '1', subject: '英文'),
        ],
        periodTimes: {
          '1': PeriodTime(startTime: '08:00', endTime: '08:50'),
        },
        curriculum: {
          '英文': CourseInfo(
            count: 3,
            schedule: [CourseSchedule(weekday: '一', period: '1')],
          ),
        },
      );
      final jsonStr = data.toJsonString();
      final restored = TimetableData.fromJsonString(jsonStr);
      expect(restored, isNotNull);
      expect(restored!.entries.length, 1);
      expect(restored.entries[0].subject, '英文');
      expect(restored.periodTimes['1']!.startTime, '08:00');
    });

    test('fromJsonString returns null for invalid input', () {
      expect(TimetableData.fromJsonString('not json'), isNull);
    });

    test('fromJson with alternative keys', () {
      final json = {
        'timetable': [
          {'day': '五', 'section': '3', 'course': '化學'},
        ],
        'periods': {
          '3': {'start_time': '10:10', 'end_time': '11:00'},
        },
        'classes': {},
      };
      final data = TimetableData.fromJson(json);
      expect(data.entries.length, 1);
      expect(data.entries[0].subject, '化學');
    });
  });

  group('SubjectAbsence', () {
    test('fromJson parses all fields with computed defaults', () {
      final json = {
        'subject': '數學',
        'truancy': 2,
        'personalLeave': 3,
        'totalClasses': 36,
      };
      final sa = SubjectAbsence.fromJson(json);
      expect(sa.subject, '數學');
      expect(sa.truancy, 2);
      expect(sa.personalLeave, 3);
      expect(sa.total, 5);
      expect(sa.totalClasses, 36);
      expect(sa.percentage, 14);
    });

    test('fromJson with explicit total', () {
      final json = {
        'subject': '英文',
        'truancy': 1,
        'personalLeave': 1,
        'total': 10,
        'totalClasses': 36,
        'percentage': 28,
      };
      final sa = SubjectAbsence.fromJson(json);
      expect(sa.total, 10);
      expect(sa.percentage, 28);
    });
  });

  group('NoticeItem', () {
    test('fromJson parses all fields', () {
      final json = {
        'link': 'https://school.tw/notice/1',
        'title': 'Holiday',
        'publisher': 'Admin',
        'date': '2024-06-01',
        'views': '100',
      };
      final item = NoticeItem.fromJson(json);
      expect(item.link, 'https://school.tw/notice/1');
      expect(item.title, 'Holiday');
      expect(item.publisher, 'Admin');
      expect(item.date, '2024-06-01');
      expect(item.views, '100');
    });

    test('fromJson with alternative keys', () {
      final json = {
        'href': '/n/2',
        'subject': 'Exam',
        'department': 'Academic',
        'publish_date': '2024-07-01',
        'hits': 50,
      };
      final item = NoticeItem.fromJson(json);
      expect(item.link, '/n/2');
      expect(item.title, 'Exam');
      expect(item.publisher, 'Academic');
      expect(item.date, '2024-07-01');
    });
  });

  group('VocPassUser', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'u1',
        'name': 'Alice',
        'username': 'alice123',
        'email': 'alice@example.com',
        'avatar': 'https://img/avatar.png',
        'email_visibility': true,
        'verified': true,
        'share_status': true,
        'school': '鶯歌工商',
      };
      final user = VocPassUser.fromJson(json);
      expect(user.id, 'u1');
      expect(user.name, 'Alice');
      expect(user.username, 'alice123');
      expect(user.email, 'alice@example.com');
      expect(user.avatarURL, 'https://img/avatar.png');
      expect(user.emailVisibility, true);
      expect(user.verified, true);
      expect(user.shareStatus, true);
      expect(user.verifiedSchool, '鶯歌工商');
      expect(user.displayName, 'Alice');
    });

    test('displayName falls back to username when name is empty', () {
      final json = {
        'id': 'u2',
        'name': '',
        'username': 'bob456',
        'email': '',
      };
      final user = VocPassUser.fromJson(json);
      expect(user.displayName, 'bob456');
    });

    test('avatarURL returns null for empty avatar', () {
      final json = {
        'id': 'u3',
        'name': '',
        'username': 'carol',
        'email': '',
        'avatar': '',
      };
      final user = VocPassUser.fromJson(json);
      expect(user.avatarURL, isNull);
    });

    test('verifiedSchool returns null for blank school', () {
      final json = {
        'id': 'u4',
        'name': '',
        'username': 'dave',
        'email': '',
        'school': '   ',
      };
      final user = VocPassUser.fromJson(json);
      expect(user.verifiedSchool, isNull);
    });

    test('shareStatus is null when key not present', () {
      final json = {
        'id': 'u5',
        'name': '',
        'username': 'eve',
        'email': '',
      };
      final user = VocPassUser.fromJson(json);
      expect(user.shareStatus, isNull);
    });
  });

  group('VocPassPublicUser', () {
    test('fromJson parses fields', () {
      final json = {
        'id': 'pu1',
        'name': 'Public Alice',
        'username': 'palice',
        'avatar': 'https://img/a.png',
      };
      final user = VocPassPublicUser.fromJson(json);
      expect(user.id, 'pu1');
      expect(user.displayName, 'Public Alice');
      expect(user.avatarURL, 'https://img/a.png');
    });

    test('displayName falls back to username', () {
      final json = {'id': 'pu2', 'name': '', 'username': 'pub_user'};
      final user = VocPassPublicUser.fromJson(json);
      expect(user.displayName, 'pub_user');
    });
  });

  group('Restaurant', () {
    test('fromJson parses all fields including map', () {
      final json = {
        'id': 'r1',
        'name': 'Cafe A',
        'school': '鶯歌工商',
        'icon': 'https://img/cafe.png',
        'map': {'lon': 121.35, 'lat': 24.95},
        'user': 'u1',
        'address': '100 Main St',
      };
      final r = Restaurant.fromJson(json);
      expect(r.id, 'r1');
      expect(r.name, 'Cafe A');
      expect(r.iconURL, 'https://img/cafe.png');
      expect(r.map!.lon, 121.35);
      expect(r.map!.lat, 24.95);
      expect(r.address, '100 Main St');
    });

    test('iconURL returns null for empty icon', () {
      final json = {'id': 'r2', 'name': 'B', 'school': 's', 'icon': ''};
      final r = Restaurant.fromJson(json);
      expect(r.iconURL, isNull);
    });
  });

  group('RestaurantEvaluation', () {
    test('fromJson and plainDescription strip HTML', () {
      final json = {
        'id': 'e1',
        'title': 'Great food',
        'description': '<p>Really <b>good</b>!</p>',
        'score': 5,
        'user': 'u1',
      };
      final eval = RestaurantEvaluation.fromJson(json);
      expect(eval.title, 'Great food');
      expect(eval.score, 5);
      expect(eval.plainDescription, 'Really good!');
    });
  });

  group('RestaurantMenu', () {
    test('fromJson parses fields', () {
      final json = {
        'id': 'm1',
        'menu': 'https://img/menu.png',
        'restaurant': 'r1',
        'user': 'u1',
      };
      final menu = RestaurantMenu.fromJson(json);
      expect(menu.id, 'm1');
      expect(menu.menuURL, 'https://img/menu.png');
      expect(menu.restaurant, 'r1');
    });

    test('menuURL returns null for empty menu', () {
      final json = {'id': 'm2', 'menu': '', 'restaurant': 'r2', 'user': 'u2'};
      final menu = RestaurantMenu.fromJson(json);
      expect(menu.menuURL, isNull);
    });
  });

  group('PeriodTime', () {
    test('fromMap and toJson roundtrip', () {
      final json = {'startTime': '08:00', 'endTime': '08:50'};
      final pt = PeriodTime.fromMap(json);
      expect(pt.startTime, '08:00');
      expect(pt.endTime, '08:50');
      final output = pt.toJson();
      expect(output['startTime'], '08:00');
      expect(output['endTime'], '08:50');
    });
  });

  group('CourseExtra', () {
    test('fromJson and toJson roundtrip', () {
      final json = {'room': 'A101', 'teacher': 'Mr. Smith'};
      final ce = CourseExtra.fromJson(json);
      expect(ce.room, 'A101');
      expect(ce.teacher, 'Mr. Smith');
      final output = ce.toJson();
      expect(output['room'], 'A101');
      expect(output['teacher'], 'Mr. Smith');
    });

    test('default constructor has empty strings', () {
      final ce = CourseExtra();
      expect(ce.room, '');
      expect(ce.teacher, '');
    });
  });
}
