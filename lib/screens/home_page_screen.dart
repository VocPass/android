import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/vocpass_auth_service.dart';
import 'following_screen.dart';
import 'restaurant_screen.dart';
import 'w2m/w2m_list_screen.dart';
import 'wallpaper/wallpaper_template_list_screen.dart';

/// 首頁 - 對應 iOS 的 HomePageView
class HomePageScreen extends StatelessWidget {
  const HomePageScreen({super.key});

  /// 卡片圖示統一使用的強調色
  static const Color _accent = Color(0xFF2DD4E0);

  @override
  Widget build(BuildContext context) {
    final vocPassAuth = context.watch<VocPassAuthService>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 大標題
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '首頁',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // 頭像 / VocPass 登入（置中）
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (vocPassAuth.isLoggedIn &&
                      vocPassAuth.currentUser != null) ...[
                    CircleAvatar(
                      radius: 44,
                      backgroundImage:
                          vocPassAuth.currentUser!.avatarURL != null
                              ? NetworkImage(vocPassAuth.currentUser!.avatarURL!)
                              : null,
                      child: vocPassAuth.currentUser!.avatarURL == null
                          ? const Icon(Icons.person,
                              size: 44, color: Colors.blue)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      vocPassAuth.currentUser!.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${vocPassAuth.currentUser!.username}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ] else ...[
                    const Icon(Icons.school, size: 64, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text(
                      'VocPass',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final uri =
                            Uri.parse('${AppConfig.vocPassApiHost}/auth');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('登入 VocPass 帳號'),
                    ),
                  ],
                ],
              ),

              const Spacer(flex: 4),

              // 2x2 功能卡片（置底）
              Row(
                children: [
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.calendar_month,
                      label: '出來玩',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const W2MListScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.auto_fix_high,
                      label: '課表產生器',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const WallpaperTemplateListScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.restaurant,
                      label: '吃啥？',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RestaurantScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _HomeCard(
                      icon: Icons.people,
                      label: '不揪？',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FollowingListScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 明顯一點的卡片底色：深色用較亮的灰、淺色用純白。
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1.35,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 30, color: HomePageScreen._accent),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
