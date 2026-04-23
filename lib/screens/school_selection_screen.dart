import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/school_config.dart';
import '../services/school_config_manager.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  bool _showBeta = false;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => SchoolConfigManager.instance.loadSchools());
  }

  List<SchoolConfig> _filteredSchools(SchoolConfigManager manager) {
    final source = manager.allSchools;
    final betaFiltered =
        source.where((school) => school.beta == _showBeta).toList();
    final keyword = _searchText.trim();
    if (keyword.isEmpty) return betaFiltered;
    return betaFiltered.where((school) {
      final appName = school.app ?? '';
      return school.name.contains(keyword) ||
          school.vision.contains(keyword) ||
          appName.contains(keyword) ||
          school.api.contains(keyword);
    }).toList();
  }

  Future<void> _openApplyForm() async {
    final uri = Uri.parse('https://vocpass.com/apply');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SchoolConfigManager>(
      builder: (context, manager, _) {
        final filtered = _filteredSchools(manager);
        if(kDebugMode){
          print("[vocPass] $manager");
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.account_balance,
                  size: 64,
                  color: _showBeta ? Colors.orange : Colors.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  '選擇學校',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '請選擇您就讀的學校',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: '搜尋學校',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => _searchText = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildBody(manager, filtered),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openApplyForm,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('申請新增學校'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(SchoolConfigManager manager, List<SchoolConfig> filtered) {
    if (manager.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if(kDebugMode){
      print("[vocPass-log] $filtered");
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('找不到符合的學校'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _SchoolRow(
          school: SchoolConfig.guest,
          onTap: () => manager.selectSchool(SchoolConfig.guest),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            '訪客模式不需登入，可直接使用課表功能（手動輸入）。',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        ...List.generate(filtered.length * 2 - (filtered.isEmpty ? 0 : 1), (i) {
          if (i.isOdd) return const SizedBox(height: 8);
          return _SchoolRow(
            school: filtered[i ~/ 2],
            onTap: () => manager.selectSchool(filtered[i ~/ 2]),
          );
        }),
      ],
    );
  }
}

class _SchoolRow extends StatelessWidget {
  final SchoolConfig school;
  final VoidCallback onTap;

  const _SchoolRow({required this.school, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGuest = school.isGuest;
    final tint = isGuest ? Colors.green : Colors.blue;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: tint.withOpacity(0.1),
                child: Icon(
                  isGuest ? Icons.person_outline : Icons.school,
                  color: tint,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuest ? '免登入 · 僅支援課表' : school.api,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isGuest ? tint : Colors.grey[600],
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
