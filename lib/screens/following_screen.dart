import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/vocpass_auth_service.dart';
import 'unsupported_screen.dart';

// MARK: - 追蹤名單

class FollowingListScreen extends StatefulWidget {
  const FollowingListScreen({super.key});

  @override
  State<FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  late List<String> _followed;
  final Map<String, VocPassPublicUser> _profiles = {};

  @override
  void initState() {
    super.initState();
    _followed = List.from(CacheService.instance.followedUsernames);
    for (final username in _followed) {
      _fetchProfile(username);
    }
  }

  Future<void> _fetchProfile(String username) async {
    try {
      final profile = await VocPassAuthService.instance.fetchUser(username);
      if (!mounted) return;
      setState(() => _profiles[username] = profile);
    } catch (_) {}
  }

  void _showAddDialog() {
    String input = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增追蹤'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: '輸入對方的 VocPass 用戶名稱'),
          autocorrect: false,
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = input.trim();
              if (name.isNotEmpty && !_followed.contains(name)) {
                setState(() => _followed.add(name));
                CacheService.instance.followedUsernames = _followed;
                _fetchProfile(name);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('新增'),
          ),
        ],
      ),
    );
  }

  void _removeAt(int index) {
    setState(() => _followed.removeAt(index));
    CacheService.instance.followedUsernames = _followed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已追蹤課表'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_followed.isEmpty) {
      return const UnsupportedScreen(
        title: '尚無追蹤對象',
        message: '點擊右上角「+」新增用戶名稱',
        showRetry: false,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _followed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final username = _followed[index];
        final profile = _profiles[username];
        return Card(
          child: ListTile(
            leading: _AvatarWidget(avatarUrl: profile?.avatarURL),
            title: profile?.name.isNotEmpty == true
                ? Text(profile!.name)
                : Text('@$username'),
            subtitle: profile?.name.isNotEmpty == true
                ? Text(
                    '@$username',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => _removeAt(index),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SharedCurriculumScreen(
                  username: username,
                  publicProfile: profile,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// MARK: - 他人課表（唯讀）

class SharedCurriculumScreen extends StatefulWidget {
  final String username;
  final VocPassPublicUser? publicProfile;

  const SharedCurriculumScreen({
    super.key,
    required this.username,
    this.publicProfile,
  });

  @override
  State<SharedCurriculumScreen> createState() => _SharedCurriculumScreenState();
}

class _SharedCurriculumScreenState extends State<SharedCurriculumScreen> {
  Map<String, CourseInfo> _curriculum = {};
  bool _isLoading = true;
  String? _error;

  static const _weekdays = ['一', '二', '三', '四', '五'];
  static const _periodOrder = [
    '早讀', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
  ];

  List<String> get _periods {
    final all = _curriculum.values
        .expand((info) => info.schedule.map((s) => s.period))
        .toSet()
        .where((p) => p.isNotEmpty)
        .toList();
    if (all.isEmpty) return const ['一', '二', '三', '四', '五', '六', '七', '八'];
    all.sort((a, b) {
      final ia = _periodOrder.indexOf(a);
      final ib = _periodOrder.indexOf(b);
      final sa = ia == -1 ? 9999 : ia;
      final sb = ib == -1 ? 9999 : ib;
      if (sa != sb) return sa.compareTo(sb);
      return (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);
    });
    return all;
  }

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
      final timetable = await api.fetchSharedCurriculum(widget.username);
      if (!mounted) return;
      setState(() {
        _curriculum = timetable.curriculum;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _subjectAt(String weekday, String period) {
    for (final entry in _curriculum.entries) {
      for (final s in entry.value.schedule) {
        if (s.weekday == weekday && s.period == period) return entry.key;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username} 的課表'),
      ),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildCurriculumGrid()],
      ),
    );
  }

  Widget _buildCurriculumGrid() {
    final periods = _periods;
    final tableRows = <TableRow>[];

    tableRows.add(TableRow(children: [
      _headerCell('節次'),
      ..._weekdays.map((day) => _headerCell('週$day')),
    ]));

    for (final period in periods) {
      tableRows.add(TableRow(children: [
        _periodCell(period),
        ..._weekdays.map((day) => _subjectCell(_subjectAt(day, period))),
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
}

// MARK: - Avatar widget

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;

  const _AvatarWidget({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.account_circle, size: 40, color: Colors.grey),
        ),
      );
    }
    return const Icon(Icons.account_circle, size: 40, color: Colors.grey);
  }
}
