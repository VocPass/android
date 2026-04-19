import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'unsupported_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceStatistics _statistics = AttendanceStatistics.empty();
  List<SubjectAbsence> _subjectAbsences = [];
  List<AbsenceRecord> _allRecords = [];
  Map<String, String> _courseMapping = {};
  bool _isLoading = true;
  String? _error;
  bool _unsupported = false;
  bool _excludeNonStandard = true;
  final _searchController = TextEditingController();
  String _searchText = '';

  static const _standardPeriods = {'1', '2', '3', '4', '5', '6', '7'};

  @override
  void initState() {
    super.initState();
    _loadPref();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _excludeNonStandard = prefs.getBool('excludeNonStandardPeriods') ?? true;
      });
    }
  }

  Future<void> _savePref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('excludeNonStandardPeriods', value);
  }

  List<AbsenceRecord> get _filteredRecords {
    var records = _allRecords;
    if (_excludeNonStandard) {
      records = records.where((r) => _standardPeriods.contains(r.period)).toList();
    }
    if (_searchText.isEmpty) return records;
    final q = _searchText.toLowerCase();
    return records.where((r) =>
      r.date.toLowerCase().contains(q) ||
      r.status.contains(_searchText) ||
      r.weekday.contains(_searchText) ||
      r.period.contains(_searchText) ||
      r.academicYear.contains(_searchText),
    ).toList();
  }

  List<({String date, List<AbsenceRecord> records})> get _groupedRecords {
    final filtered = _filteredRecords;
    final grouped = <String, List<AbsenceRecord>>{};
    for (final r in filtered) {
      (grouped[r.date] ??= []).add(r);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return dates.map((date) {
      final sorted = grouped[date]!..sort((a, b) => a.period.compareTo(b.period));
      return (date: date, records: sorted);
    }).toList();
  }

  AttendanceStatistics get _filteredStatistics {
    if (!_excludeNonStandard) return _statistics;
    final filtered = _allRecords.where((r) => _standardPeriods.contains(r.period)).toList();
    return _recompute(filtered);
  }

  AttendanceStatistics _recompute(List<AbsenceRecord> records) {
    final first = <String, String>{};
    final second = <String, String>{};
    var truancy = 0, personal = 0, sick = 0, official = 0;
    const mapping = {'曠': '曠課', '事': '事假', '病': '病假', '公': '公假'};
    for (final r in records) {
      final key = mapping[r.status] ?? r.status;
      if (r.academicYear == '上') {
        final c = int.tryParse(first[key] ?? '0') ?? 0;
        first[key] = (c + 1).toString();
      } else {
        final c = int.tryParse(second[key] ?? '0') ?? 0;
        second[key] = (c + 1).toString();
      }
      switch (r.status) {
        case '曠': truancy++; break;
        case '事': personal++; break;
        case '病': sick++; break;
        case '公': official++; break;
      }
    }
    return AttendanceStatistics(
      firstSemester: first,
      secondSemester: second,
      total: AttendanceTotals(truancy: truancy, personalLeave: personal, sickLeave: sick, officialLeave: official),
      statisticsDate: _statistics.statisticsDate,
    );
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final result = await api.fetchAttendanceWithCurriculum();
      setState(() {
        _allRecords = result.records;
        _statistics = result.statistics;
        _subjectAbsences = result.subjectAbsences;
        _courseMapping = result.courseMapping;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.featureNotSupported) {
        setState(() { _unsupported = true; _isLoading = false; });
      } else {
        setState(() { _error = e.message; _isLoading = false; });
      }
    } catch (_) {
      setState(() { _error = '缺曠資料載入失敗'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缺曠統計'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('僅 1~7 節'),
              selected: _excludeNonStandard,
              onSelected: (v) {
                setState(() => _excludeNonStandard = v);
                _savePref(v);
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_unsupported) {
      return const UnsupportedScreen(title: '此功能不支援', message: '目前選擇的學校尚未支援此功能');
    }
    if (_error != null) {
      return UnsupportedScreen(title: '載入失敗', message: _error!, onRetry: _loadData);
    }

    final stats = _filteredStatistics;
    final grouped = _groupedRecords;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SearchBar(
            controller: _searchController,
            hintText: '搜尋日期、類型、節次...',
            leading: const Icon(Icons.search),
            trailing: _searchText.isNotEmpty
                ? [IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())]
                : null,
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_searchText.isEmpty) ...[
                  _buildSummarySection(stats),
                  const SizedBox(height: 12),
                  Text('各科缺曠統計', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_subjectAbsences.isEmpty)
                    const _EmptyTile(message: '無缺曠記錄')
                  else
                    ..._subjectAbsences
                        .where((e) => e.total > 0)
                        .map((a) => _SubjectAbsenceCard(absence: a)),
                  const SizedBox(height: 12),
                  Text('缺曠明細', style: Theme.of(context).textTheme.titleMedium),
                ] else
                  Text('搜尋結果（${grouped.length} 天）',
                      style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (grouped.isEmpty)
                  _EmptyTile(message: _searchText.isEmpty ? '無缺曠記錄' : '找不到符合的記錄')
                else
                  ...grouped.map((g) => _AbsenceDayRow(
                        date: g.date,
                        records: g.records,
                        courseMapping: _courseMapping,
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(AttendanceStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('缺曠總覽', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (stats.firstSemester.isNotEmpty)
          _SemesterCard(title: '上學期', data: stats.firstSemester),
        if (stats.secondSemester.isNotEmpty)
          _SemesterCard(title: '下學期', data: stats.secondSemester),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('全年合計', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _TotalsRow(total: stats.total),
              ],
            ),
          ),
        ),
        if (stats.statisticsDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(stats.statisticsDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ),
      ],
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final String title;
  final Map<String, String> data;

  const _SemesterCard({required this.title, required this.data});

  int _getValue(String key) => int.tryParse(data[key] ?? '0') ?? 0;
  int get _personalLeave => _getValue('事假') + _getValue('事假1');
  int get _sickLeave => _getValue('病假') + _getValue('病假1') + _getValue('病假2');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title 合計', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              _StatChip(label: '曠課', value: _getValue('曠課'), color: Colors.red),
              _StatChip(label: '事假', value: _personalLeave, color: Colors.orange),
              _StatChip(label: '病假', value: _sickLeave, color: Colors.blue),
              _StatChip(label: '公假', value: _getValue('公假'), color: Colors.green),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final AttendanceTotals total;
  const _TotalsRow({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatChip(label: '曠課', value: total.truancy, color: Colors.red),
      _StatChip(label: '事假', value: total.personalLeave, color: Colors.orange),
      _StatChip(label: '病假', value: total.sickLeave, color: Colors.blue),
      _StatChip(label: '公假', value: total.officialLeave, color: Colors.green),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value.toString(),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Colors.grey[700])),
        ]),
      ),
    );
  }
}

class _SubjectAbsenceCard extends StatelessWidget {
  final SubjectAbsence absence;
  const _SubjectAbsenceCard({required this.absence});

  Color get _color {
    if (absence.percentage >= 33) return Colors.red;
    if (absence.percentage >= 25) return Colors.orange;
    if (absence.percentage >= 17) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(absence.subject, style: Theme.of(context).textTheme.titleSmall)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${absence.percentage}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: _color)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _Badge(text: '曠 ${absence.truancy}', color: Colors.red),
            const SizedBox(width: 6),
            _Badge(text: '事 ${absence.personalLeave}', color: Colors.orange),
            const SizedBox(width: 6),
            _Badge(text: '總 ${absence.total}/${absence.totalClasses}', color: Colors.grey),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: absence.percentage / 100,
              backgroundColor: Colors.grey.shade200,
              color: _color,
              minHeight: 6,
            ),
          ),
        ]),
      ),
    );
  }
}

class _AbsenceDayRow extends StatelessWidget {
  final String date;
  final List<AbsenceRecord> records;
  final Map<String, String> courseMapping;

  const _AbsenceDayRow({
    required this.date,
    required this.records,
    required this.courseMapping,
  });

  static const _numberMap = {
    '1': '一', '2': '二', '3': '三', '4': '四',
    '5': '五', '6': '六', '7': '七',
  };

  static String get _currentSemesterLabel {
    final month = DateTime.now().month;
    return (month > 8 || month < 3) ? '上' : '下';
  }

  String? _subject(AbsenceRecord r) {
    if (r.academicYear != _currentSemesterLabel) return null;
    final chinesePeriod = _numberMap[r.period] ?? r.period;
    return courseMapping['${r.weekday}-$chinesePeriod'];
  }

  Color _statusColor(String status) {
    switch (status) {
      case '曠': case '曠課': return Colors.red;
      case '事': case '事假': return Colors.orange;
      case '病': case '病假': return Colors.blue;
      case '公': case '公假': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstRecord = records.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (firstRecord.weekday.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(firstRecord.weekday,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
            if (firstRecord.academicYear.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${firstRecord.academicYear}學期',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: records.map((r) {
                final color = _statusColor(r.status);
                final subjectName = _subject(r);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(r.status,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (subjectName != null || r.period.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if (subjectName != null)
                          Text(subjectName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        if (r.period.isNotEmpty)
                          Text('第${r.period}節', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ]),
                    ],
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String message;
  const _EmptyTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 12),
          Text(message),
        ]),
      ),
    );
  }
}
