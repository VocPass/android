import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/school_config_manager.dart';
import '../services/vocpass_auth_service.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = 'unknown';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final cache = context.watch<CacheService>();
    final schoolManager = context.watch<SchoolConfigManager>();
    final vocPassAuth = context.watch<VocPassAuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // VocPass 帳號
          Text('VocPass 帳號', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (vocPassAuth.isLoggedIn && vocPassAuth.currentUser != null) ...[
                  ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: vocPassAuth.currentUser!.avatarURL != null
                          ? NetworkImage(vocPassAuth.currentUser!.avatarURL!)
                          : null,
                      child: vocPassAuth.currentUser!.avatarURL == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(vocPassAuth.currentUser!.displayName),
                    subtitle: Text('@${vocPassAuth.currentUser!.username}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('編輯個人資料'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.people),
                    title: const Text('分享課表'),
                    subtitle: const Text('讓其他人可以追蹤你的課表'),
                    value: cache.isCurriculumSharing,
                    onChanged: (value) async {
                      try {
                        await api.setCurriculumSharing(value);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('登出 VocPass'),
                    onTap: vocPassAuth.logout,
                  ),
                ] else
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('登入 VocPass'),
                    subtitle: const Text('登入後可追蹤他人課表、分享課表'),
                    onTap: () => _openUrl('${AppConfig.vocPassApiHost}/auth'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 學校設定
          Text('學校設定', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (schoolManager.selectedSchool != null)
                  ListTile(
                    leading: const Icon(Icons.school),
                    title: const Text('目前學校'),
                    subtitle: Text(schoolManager.selectedSchool!.name),
                  ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('切換學校'),
                  onTap: () {
                    schoolManager.clearSelectedSchool();
                    api.logout();
                  },
                ),
                if (api.isLoggedIn)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('登出學校帳號'),
                    onTap: api.logout,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 課表設定
          Text('課表', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: const Text('每天節數'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: cache.periodsPerDay > 1
                            ? () => cache.periodsPerDay = cache.periodsPerDay - 1
                            : null,
                      ),
                      Text('${cache.periodsPerDay} 節'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: cache.periodsPerDay < 12
                            ? () => cache.periodsPerDay = cache.periodsPerDay + 1
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('課表固定顯示的節數，即使該節無課也會顯示。預設 7 節。',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),

          const SizedBox(height: 16),

          // 缺曠統計
          Text('缺曠統計', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('每學期週數'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: cache.weeksPerSemester > 10
                            ? () => cache.weeksPerSemester = cache.weeksPerSemester - 1
                            : null,
                      ),
                      Text('${cache.weeksPerSemester} 週'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: cache.weeksPerSemester < 25
                            ? () => cache.weeksPerSemester = cache.weeksPerSemester + 1
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('用於計算各科缺曠百分比，預設 18 週。',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),

          const SizedBox(height: 16),

          // 關於
          Text('關於', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('版本'),
                  trailing: Text(_version,
                      style: const TextStyle(color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('GitHub'),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  onTap: () => _openUrl('https://github.com/VocPass'),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('官網'),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  onTap: () => _openUrl('https://VocPass.com'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 開發者
          Text('開發者', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              title: const Text('Cookies'),
              children: [
                if (api.cookies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('尚無 Cookies'),
                  )
                else
                  ...api.cookies.map((cookie) => ListTile(
                        title: Text(cookie.name, style: const TextStyle(fontSize: 12)),
                        subtitle: Text(cookie.value,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
