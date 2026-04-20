import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/w2m_models.dart';
import '../../services/vocpass_auth_service.dart';
import '../../services/w2m_service.dart';
import 'w2m_create_event_screen.dart';
import 'w2m_result_screen.dart';

class W2MListScreen extends StatefulWidget {
  const W2MListScreen({super.key});

  @override
  State<W2MListScreen> createState() => _W2MListScreenState();
}

class _W2MListScreenState extends State<W2MListScreen> {
  W2MEventListResponse? _eventList;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final auth = VocPassAuthService.instance;
    if (auth.isLoggedIn) _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await W2MService.instance.fetchEvents();
      if (mounted) setState(() => _eventList = list);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<VocPassAuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('出來玩'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: auth.isLoggedIn
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const W2MCreateEventScreen()),
                    );
                    if (auth.isLoggedIn) _loadEvents();
                  }
                : null,
          ),
        ],
      ),
      body: _buildBody(auth),
    );
  }

  Widget _buildBody(VocPassAuthService auth) {
    if (!auth.isLoggedIn) return _notLoggedInView();
    if (_isLoading && _eventList == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) return _errorView(_errorMessage!);
    return _listContent();
  }

  Widget _listContent() {
    final list = _eventList;
    if (list == null) return const Center(child: CircularProgressIndicator());

    final isEmpty = list.created.isEmpty && list.participated.isEmpty;

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: isEmpty
          ? ListView(
              children: [_emptyView()],
            )
          : ListView(
              children: [
                if (list.created.isNotEmpty) ...[
                  _sectionHeader('我建立的'),
                  ...list.created.map((e) => _eventTile(e)),
                ],
                if (list.participated.isNotEmpty) ...[
                  _sectionHeader('我參與的'),
                  ...list.participated.map((e) => _eventTile(e)),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _eventTile(W2MEventSummary event) {
    final datesPreview = event.dates.take(3).join('、') +
        (event.dates.length > 3 ? '…' : '');

    return ListTile(
      title: Text(event.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_today, size: 11, color: Colors.grey),
            const SizedBox(width: 4),
            Text(datesPreview,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          Row(children: [
            const Icon(Icons.person_outline, size: 11, color: Colors.grey),
            const SizedBox(width: 4),
            Text(event.creator.displayName,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => W2MResultScreen(
              eventID: event.id,
              creatorID: event.creator.id,
            ),
          ),
        );
        _loadEvents();
      },
    );
  }

  Widget _emptyView() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          children: [
            Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('還沒有活動',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            SizedBox(height: 8),
            Text('點右上角 + 建立第一個活動',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );

  Widget _notLoggedInView() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('登入後才能使用出來玩',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('請先登入 VocPass 帳號',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );

  Widget _errorView(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadEvents,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
}
