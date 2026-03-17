import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'unsupported_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MeritDemeritRecord> _merits = [];
  List<MeritDemeritRecord> _demerits = [];
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
      final result = await api.fetchMeritDemeritRecords();
      setState(() {
        _merits = result.$1;
        _demerits = result.$2;
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
    } catch (e) {
      setState(() {
        _error = '資料載入失敗';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('獎懲記錄')),
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
          _buildSection('獎勵', _merits, isMerit: true),
          const SizedBox(height: 16),
          _buildSection('懲罰', _demerits, isMerit: false),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<MeritDemeritRecord> records,
      {required bool isMerit}) {
    if (records.isEmpty) {
      return _EmptyCard(title: title, message: '無$title記錄');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${records.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...records.map((record) => _MeritCard(
              record: record,
              isMerit: isMerit,
            )),
      ],
    );
  }
}

class _MeritCard extends StatelessWidget {
  final MeritDemeritRecord record;
  final bool isMerit;

  const _MeritCard({required this.record, required this.isMerit});

  @override
  Widget build(BuildContext context) {
    final color = isMerit ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  record.action,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color),
                ),
                const Spacer(),
                Text(
                  record.year,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(record.reason),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  record.dateOccurred,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
                if (record.dateRevoked != null) ...[
                  const Spacer(),
                  Text(
                    '已銷過: ${record.dateRevoked}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange),
                  ),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyCard({required this.title, required this.message});

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
