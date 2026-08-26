import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/school_config_manager.dart';
import '../widgets/grouped_list.dart';
import 'attendance_screen.dart';
import 'curriculum_screen.dart';
import 'data_export_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'original_system_screen.dart';
import 'school_notice_screen.dart';
import 'score_screen.dart';

/// 校務 - 對應 iOS 的 SchoolAffairsView
class SchoolAffairsScreen extends StatelessWidget {
  const SchoolAffairsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final schoolManager = context.watch<SchoolConfigManager>();
    final school = schoolManager.selectedSchool;

    return Scaffold(
      appBar: AppBar(title: const Text('校務')),
      body: _buildBody(context, api, schoolManager, school),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ApiService api,
    SchoolConfigManager schoolManager,
    dynamic school,
  ) {
    if (school == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('尚未選擇學校',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                schoolManager.clearSelectedSchool();
              },
              child: const Text('選擇學校'),
            ),
          ],
        ),
      );
    }

    // 訪客模式：僅顯示課表
    if (school.isGuest) {
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          GroupedCard(
            children: [
              _SchoolAffairsTile(
                icon: Icons.calendar_month,
                title: '課表',
                enabled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CurriculumScreen()),
                ),
              ),
            ],
          ),
          const SectionFootnote('訪客模式下僅可使用課表功能，課程內容可手動輸入。'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // 登入提示
        if (!api.isLoggedIn) ...[
          GroupedCard(
            children: [
              ListTile(
                leading: const Icon(Icons.key),
                title: const Text('登入學校帳號以使用校務功能'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  final loginUrl = school.loginUrl;
                  if (loginUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LoginScreen(school: school, targetUrl: loginUrl),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 公告 & 分機
        if (school.notice != null ||
            (school.telephone != null && school.telephone.isNotEmpty)) ...[
          GroupedCard(
            children: [
              if (school.notice != null)
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('公告'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SchoolNoticeScreen()),
                  ),
                ),
              if (school.telephone != null && school.telephone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('分機查詢'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    final uri = Uri.parse(school.telephone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 校務功能
        const SectionHeader('校務功能'),
        GroupedCard(
          children: [
            _SchoolAffairsTile(
              icon: Icons.star,
              title: '獎懲',
              enabled: api.isLoggedIn,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
            ),
            _SchoolAffairsTile(
              icon: Icons.calendar_month,
              title: '課表',
              enabled: true, // 可使用快取
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurriculumScreen()),
              ),
            ),
            _SchoolAffairsTile(
              icon: Icons.event_busy,
              title: '缺曠',
              enabled: api.isLoggedIn,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              ),
            ),
            _SchoolAffairsTile(
              icon: Icons.bar_chart,
              title: '成績',
              enabled: api.isLoggedIn,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScoreScreen()),
              ),
            ),
          ],
        ),

        // 資料匯出
        const SizedBox(height: 8),
        GroupedCard(
          children: [
            _SchoolAffairsTile(
              icon: Icons.download,
              title: '資料匯出',
              enabled: api.isLoggedIn,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataExportScreen()),
              ),
            ),
          ],
        ),
        const SectionFootnote('將校務資料匯出成 JSON 檔，可到線上工具開啟檢視。'),

        // 前往原系統
        if (school.indexUrl != null) ...[
          const SizedBox(height: 8),
          GroupedCard(
            children: [
              _SchoolAffairsTile(
                icon: Icons.open_in_browser,
                title: '前往原系統',
                enabled: api.isLoggedIn,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OriginalSystemScreen(
                      school: school,
                      indexUrl: school.indexUrl!,
                      cookies: api.cookies,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!api.isLoggedIn)
            const SectionFootnote('登入學校帳號後即可攜帶登入狀態前往原系統。'),
        ],
      ],
    );
  }
}

class _SchoolAffairsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  const _SchoolAffairsTile({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: enabled ? null : Colors.grey[400]),
      title: Text(title,
          style: TextStyle(color: enabled ? null : Colors.grey[400])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
