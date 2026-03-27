import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'unsupported_screen.dart';

class SchoolNoticeScreen extends StatefulWidget {
  const SchoolNoticeScreen({super.key});

  @override
  State<SchoolNoticeScreen> createState() => _SchoolNoticeScreenState();
}

class _SchoolNoticeScreenState extends State<SchoolNoticeScreen> {
  List<NoticeItem> _notices = [];
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
      _unsupported = false;
    });
    try {
      final api = context.read<ApiService>();
      final notices = await api.fetchNotices();
      setState(() {
        _notices = notices;
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
        _error = '公告載入失敗';
        _isLoading = false;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
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
        showRetry: false,
      );
    }
    if (_error != null) {
      return UnsupportedScreen(
        title: '載入失敗',
        message: _error!,
        onRetry: _loadData,
      );
    }
    if (_notices.isEmpty) {
      return const UnsupportedScreen(
        title: '尚無公告',
        message: '目前沒有任何公告',
        showRetry: false,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notice = _notices[index];
          return _NoticeCard(
            notice: notice,
            onTap: () => _openUrl(notice.link),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final NoticeItem notice;
  final VoidCallback onTap;

  const _NoticeCard({required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (notice.publisher.isNotEmpty) ...[
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      notice.publisher,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (notice.date.isNotEmpty) ...[
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      notice.date,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                  if (notice.views.isNotEmpty && notice.views != '0') ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      notice.views,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
