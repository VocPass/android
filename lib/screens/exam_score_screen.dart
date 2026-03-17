import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'unsupported_screen.dart';

class ExamScoreScreen extends StatefulWidget {
  const ExamScoreScreen({super.key});

  @override
  State<ExamScoreScreen> createState() => _ExamScoreScreenState();
}

class _ExamScoreScreenState extends State<ExamScoreScreen> {
  List<ExamMenuItem> _menu = [];
  bool _isLoading = true;
  String? _error;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final items = await api.fetchExamMenu(forceRefresh: forceRefresh);
      setState(() {
        _menu = items;
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
        _error = '考試成績載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('考試成績')),
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
        onRetry: _loadMenu,
      );
    }
    if (_menu.isEmpty) {
      return const Center(child: Text('沒有考試資料'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = _menu[index];
        return Card(
          child: ListTile(
            title: Text(item.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExamScoreDetailScreen(item: item),
                ),
              );
            },
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _menu.length,
    );
  }
}

class ExamScoreDetailScreen extends StatefulWidget {
  final ExamMenuItem item;

  const ExamScoreDetailScreen({super.key, required this.item});

  @override
  State<ExamScoreDetailScreen> createState() => _ExamScoreDetailScreenState();
}

class _ExamScoreDetailScreenState extends State<ExamScoreDetailScreen> {
  ExamScoreData _data = ExamScoreData.empty();
  bool _isLoading = true;
  String? _error;

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
      final data = await api.fetchExamScore(widget.item.fullUrl);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = '考試成績載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return UnsupportedScreen(
        title: '載入失敗',
        message: _error!,
        onRetry: _loadData,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_data.examInfo.isNotEmpty)
          Text(_data.examInfo,
              style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_data.studentInfo.studentId.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(_data.studentInfo.studentId),
              subtitle: Text(_data.studentInfo.className),
            ),
          ),
        const SizedBox(height: 16),
        Text('科目成績', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_data.subjects.isEmpty)
          const _EmptyTile(message: '無成績資料')
        else
          ..._data.subjects.map((s) => _ExamSubjectCard(score: s)),
      ],
    );
  }
}

class _ExamSubjectCard extends StatelessWidget {
  final ExamSubjectScore score;

  const _ExamSubjectCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(score.subject,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _ScoreLabel(label: '個人', value: score.personalScore)),
                Expanded(child: _ScoreLabel(label: '班均', value: score.classAverage)),
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
