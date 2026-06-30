// 論壇檢舉表單

import 'package:flutter/material.dart';

import '../../services/forum_service.dart';

const _reasons = <String>['垃圾訊息', '騷擾或霸凌', '不當內容', '假訊息', '其他'];

/// 顯示檢舉表單。傳入文章或留言 ID 其中之一。
Future<void> showForumReportSheet(
  BuildContext context, {
  String? forumPostID,
  String? forumMessageID,
}) async {
  final isPost = forumPostID != null;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ForumReportSheet(
      title: isPost ? '檢舉文章' : '檢舉留言',
      forumPostID: forumPostID,
      forumMessageID: forumMessageID,
    ),
  );
}

class _ForumReportSheet extends StatefulWidget {
  final String title;
  final String? forumPostID;
  final String? forumMessageID;

  const _ForumReportSheet({
    required this.title,
    this.forumPostID,
    this.forumMessageID,
  });

  @override
  State<_ForumReportSheet> createState() => _ForumReportSheetState();
}

class _ForumReportSheetState extends State<_ForumReportSheet> {
  String _reason = _reasons.first;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ForumService.instance.report(
        forumPostID: widget.forumPostID,
        forumMessageID: widget.forumMessageID,
        reason: _reason,
        description: _descCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已送出檢舉，感謝您的回報')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          const Text('原因', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final reason in _reasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: '補充說明（選填）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('送出檢舉'),
            ),
          ),
        ],
      ),
    );
  }
}
