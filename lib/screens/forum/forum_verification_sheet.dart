// 論壇學校驗證狀態說明

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/vocpass_auth_service.dart';

/// 顯示目前學校驗證狀態。對應 iOS 的 ForumSchoolVerificationSheet。
Future<void> showForumVerificationSheet(
  BuildContext context, {
  String? selectedSchoolName,
}) async {
  // 嘗試刷新使用者資料以取得最新驗證狀態。
  if (VocPassAuthService.instance.isLoggedIn) {
    try {
      await VocPassAuthService.instance.refreshMe();
    } catch (_) {}
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ForumVerificationSheet(selectedSchoolName: selectedSchoolName),
  );
}

class _ForumVerificationSheet extends StatelessWidget {
  final String? selectedSchoolName;

  const _ForumVerificationSheet({this.selectedSchoolName});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<VocPassAuthService>();
    final verified = auth.currentUser?.verifiedSchool;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('驗證學校', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // 目前狀態
          Row(
            children: [
              Icon(
                verified == null ? Icons.cancel : Icons.verified,
                color: verified == null ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                verified ?? '尚未驗證學校',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: verified == null ? Colors.grey : Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          if (selectedSchoolName != null)
            _row('目前瀏覽學校', selectedSchoolName!),
          _row('你的學校', verified ?? '未驗證'),

          const SizedBox(height: 20),
          Text('如何完成驗證',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            '需要同時登入過學校帳號和 VocPass 帳號。完成後，你的學校欄位會顯示學校名稱；'
            '若未驗證成功可嘗試重新打開 App 或重新登入學校帳號。',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
