import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  bool _isLoading = true;
  String? _error;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final result = await api.fetchAttendanceWithCurriculum();
      setState(() {
        _statistics = result.$1;
        _subjectAbsences = result.$2;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.featureNotSupported) {
        setState(() {
          _unsupported = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = '缺曠資料載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('缺曠統計')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_unsupported) {
      return const UnsupportedScreen(
        title: '此功能不支援',
        message: '目前選擇的學校尚未支援此功能',
      );
    }
    if (_error != null) {
      return UnsupportedScreen(
        title: '載入失敗',
        message: _error!,
        onRetry: _loadData,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummarySection(),
          const SizedBox(height: 16),
          Text('各科缺曠統計',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_subjectAbsences.isEmpty)
            const _EmptyTile(message: '無缺曠記錄')
          else
            ..._subjectAbsences
                .where((e) => e.total > 0)
                .map((absence) => _SubjectAbsenceCard(absence: absence)),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('缺曠總覽', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_statistics.firstSemester.isNotEmpty)
          _SemesterCard(title: '上學期', data: _statistics.firstSemester),
        if (_statistics.secondSemester.isNotEmpty)
          _SemesterCard(title: '下學期', data: _statistics.secondSemester),
        const SizedBox(height: 8),
        _TotalsRow(total: _statistics.total),
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
            Text('$title 合計',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(label: '曠課', value: _getValue('曠課'), color: Colors.red),
                _StatChip(label: '事假', value: _personalLeave, color: Colors.orange),
                _StatChip(label: '病假', value: _sickLeave, color: Colors.blue),
                _StatChip(label: '公假', value: _getValue('公假'), color: Colors.green),
              ],
            ),
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
    return Row(
      children: [
        _StatChip(label: '曠課', value: total.truancy, color: Colors.red),
        _StatChip(label: '事假', value: total.personalLeave, color: Colors.orange),
        _StatChip(label: '病假', value: total.sickLeave, color: Colors.blue),
        _StatChip(label: '公假', value: total.officialLeave, color: Colors.green),
      ],
    );
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value.toString(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

class _SubjectAbsenceCard extends StatelessWidget {
  final SubjectAbsence absence;

  const _SubjectAbsenceCard({required this.absence});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    absence.subject,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('${absence.percentage}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _Badge(text: '曠 ${absence.truancy}', color: Colors.red),
                const SizedBox(width: 6),
                _Badge(text: '事 ${absence.personalLeave}', color: Colors.orange),
                const SizedBox(width: 6),
                _Badge(text: '總 ${absence.total}/${absence.totalClasses}', color: Colors.grey),
              ],
            ),
          ],
        ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
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
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
