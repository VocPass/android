import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'exam_score_screen.dart';
import 'unsupported_screen.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  GradeData _gradeData = GradeData.empty();
  int _selectedYear = 1;
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
      final data = await api.fetchYearScore(year: _selectedYear);
      setState(() {
        _gradeData = data;
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
        _error = '成績資料載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('學年成績'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExamScoreScreen()),
              );
            },
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
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
          _buildYearSelector(),
          const SizedBox(height: 16),
          if (_gradeData.studentInfo.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_gradeData.studentInfo),
              ),
            ),
          const SizedBox(height: 16),
          Text('科目成績', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_gradeData.subjects.isEmpty)
            const _EmptyTile(message: '無成績資料')
          else
            ..._gradeData.subjects.map((subject) => _SubjectGradeCard(subject: subject)),
          const SizedBox(height: 16),
          if (_gradeData.totalScores.isNotEmpty) ...[
            Text('總成績', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._gradeData.totalScores.entries.map((entry) => _TotalScoreCard(
                  title: entry.key,
                  score: entry.value,
                )),
            const SizedBox(height: 16),
          ],
          if (_gradeData.dailyPerformance.isNotEmpty) ...[
            Text('日常生活表現',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._gradeData.dailyPerformance.entries.map((entry) =>
                _DailyPerformanceCard(
                    title: _semesterTitle(entry.key),
                    performance: entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('一年級')),
        ButtonSegment(value: 2, label: Text('二年級')),
        ButtonSegment(value: 3, label: Text('三年級')),
      ],
      selected: {_selectedYear},
      onSelectionChanged: (value) {
        setState(() {
          _selectedYear = value.first;
        });
        _loadData();
      },
    );
  }

  String _semesterTitle(String key) {
    switch (key) {
      case 'first_semester':
        return '上學期';
      case 'second_semester':
        return '下學期';
      default:
        return key;
    }
  }
}

class _SubjectGradeCard extends StatelessWidget {
  final SubjectGrade subject;

  const _SubjectGradeCard({required this.subject});

  Color _scoreColor(String score) {
    final value = double.tryParse(score) ?? 0;
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.subject,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SemesterScoreBlock(
                    title: '上學期',
                    score: subject.firstSemester.score,
                    credit: subject.firstSemester.credit,
                    color: _scoreColor(subject.firstSemester.score),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SemesterScoreBlock(
                    title: '下學期',
                    score: subject.secondSemester.score,
                    credit: subject.secondSemester.credit,
                    color: _scoreColor(subject.secondSemester.score),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterScoreBlock extends StatelessWidget {
  final String title;
  final String score;
  final String credit;
  final Color color;

  const _SemesterScoreBlock({
    required this.title,
    required this.score,
    required this.credit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(
          score,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text('($credit 學分)',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey[600])),
      ],
    );
  }
}

class _TotalScoreCard extends StatelessWidget {
  final String title;
  final TotalScore score;

  const _TotalScoreCard({required this.title, required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _ScoreLabel(label: '上學期', value: score.firstSemester)),
                Expanded(child: _ScoreLabel(label: '下學期', value: score.secondSemester)),
                Expanded(child: _ScoreLabel(label: '學年', value: score.year)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _DailyPerformanceCard extends StatelessWidget {
  final String title;
  final DailyPerformance performance;

  const _DailyPerformanceCard({required this.title, required this.performance});

  @override
  Widget build(BuildContext context) {
    if (performance.isCompletelyEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _PerfRow(label: '評量', value: performance.evaluation),
            _PerfRow(label: '描述', value: performance.description),
            _PerfRow(label: '服務', value: performance.serviceHours),
            _PerfRow(label: '特殊表現', value: performance.specialPerformance),
            _PerfRow(label: '建議', value: performance.suggestions),
            _PerfRow(label: '其他', value: performance.others),
          ],
        ),
      ),
    );
  }
}

class _PerfRow extends StatelessWidget {
  final String label;
  final String value;

  const _PerfRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
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
