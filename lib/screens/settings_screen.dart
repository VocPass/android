import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/dynamic_island_service.dart';
import '../services/school_config_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = 'unknown';
  bool? _dynamicIslandSupported;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadDynamicIslandSupport();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  Future<void> _openGithub() async {
    final uri = Uri.parse('https://github.com/VocPass');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadDynamicIslandSupport() async {
    final supported = await DynamicIslandService.instance.isSupported();
    if (!mounted) return;
    setState(() => _dynamicIslandSupported = supported);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final cache = context.watch<CacheService>();
    final schoolManager = context.watch<SchoolConfigManager>();
    final dynamicIslandEnabled = _dynamicIslandSupported == true;
    final dynamicIslandStatusText = _dynamicIslandSupported == null
        ? '正在偵測裝置支援狀態...'
        : dynamicIslandEnabled
            ? '已偵測到相容裝置，可啟用動態島 API（實驗性）。'
            : '此裝置未偵測到動態島相容條件，功能已停用。';

    // Add showBeta variable, you can set this as needed or make it configurable
    final bool showBeta = false; // TODO: Set this to true to show beta info

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('帳號', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (schoolManager.selectedSchool != null)
                  ListTile(
                    leading: const Icon(Icons.school),
                    title: const Text('目前學校'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schoolManager.selectedSchool!.name),
                        // if (showBeta && (schoolManager.selectedSchool?.beta == true))
                        //   const Text('Beta', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('切換學校'),
                  onTap: () {
                    schoolManager.clearSelectedSchool();
                    api.logout();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('登出'),
                  onTap: api.logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Text('即時動態 / 動態島',
          //     style: Theme.of(context).textTheme.titleMedium),
          // const SizedBox(height: 8),
          // Card(
          //   child: Padding(
          //     padding: const EdgeInsets.all(12),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(dynamicIslandStatusText),
          //         const SizedBox(height: 12),
          //         SwitchListTile(
          //           contentPadding: EdgeInsets.zero,
          //           title: const Text('上課前自動顯示'),
          //           value: cache.autoStartDynamicIsland,
          //           onChanged: dynamicIslandEnabled
          //               ? (value) {
          //                   cache.autoStartDynamicIsland = value;
          //                 }
          //               : null,
          //         ),
          //         ListTile(
          //           contentPadding: EdgeInsets.zero,
          //           title: const Text('提前啟動時間'),
          //           subtitle: Text('${cache.autoStartMinutesBefore} 分鐘前'),
          //           trailing: const Icon(Icons.timer),
          //           onTap: dynamicIslandEnabled
          //               ? () async {
          //                   final result = await showModalBottomSheet<int>(
          //                     context: context,
          //                     builder: (context) => _MinutesPicker(
          //                       initial: cache.autoStartMinutesBefore,
          //                     ),
          //                   );
          //                   if (result != null) {
          //                     cache.autoStartMinutesBefore = result;
          //                   }
          //                 }
          //               : null,
          //         ),
          //         TextFormField(
          //           initialValue: cache.savedClassName,
          //           decoration: const InputDecoration(
          //             labelText: '班級名稱',
          //             hintText: '例：訊三孝',
          //           ),
          //           enabled: dynamicIslandEnabled,
          //           onChanged: (value) {
          //             cache.savedClassName = value;
          //           },
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 16),
          Text('關於', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('版本'),
                  trailing: Text(_version),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('GitHub'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _openGithub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                        title: Text(cookie.name),
                        subtitle: Text(cookie.value),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinutesPicker extends StatefulWidget {
  final int initial;

  const _MinutesPicker({required this.initial});

  @override
  State<_MinutesPicker> createState() => _MinutesPickerState();
}

class _MinutesPickerState extends State<_MinutesPicker> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('提前啟動時間',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Slider(
            value: _current.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$_current 分鐘',
            onChanged: (value) {
              setState(() => _current = value.round());
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_current),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
