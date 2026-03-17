import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'unsupported_screen.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  Map<String, CourseInfo> _curriculum = {};
  bool _isLoading = true;
  String? _error;
  bool _unsupported = false;

  final _weekdays = const ['一', '二', '三', '四', '五'];
  final _periods = const ['一', '二', '三', '四', '五', '六', '七'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final data = await api.fetchCurriculum(forceRefresh: forceRefresh);
      setState(() {
        _curriculum = data;
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
        _error = '課表載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('課表'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadData(forceRefresh: true),
            icon: const Icon(Icons.refresh),
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
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCurriculumGrid(),
        ],
      ),
    );
  }

  Widget _buildCurriculumGrid() {
    final tableRows = <TableRow>[];

    tableRows.add(TableRow(children: [
      _headerCell('節次'),
      ..._weekdays.map((day) => _headerCell('週$day')),
    ]));

    for (final period in _periods) {
      tableRows.add(TableRow(children: [
        _periodCell(period),
        ..._weekdays.map((day) => _subjectCell(_getSubject(day, period))),
      ]));
    }

    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows,
    );
  }

  Widget _headerCell(String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _periodCell(String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _subjectCell(String subject) {
    return Container(
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(
        subject,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  String _getSubject(String weekday, String period) {
    for (final entry in _curriculum.entries) {
      for (final schedule in entry.value.schedule) {
        if (schedule.weekday == weekday && schedule.period == period) {
          return entry.key;
        }
      }
    }
    return '';
  }
}
