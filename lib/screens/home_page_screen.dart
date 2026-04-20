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

  @override
  Widget build(BuildContext context) {
    final vocPassAuth = context.watch<VocPassAuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('首頁')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Avatar / VocPass Login
              if (vocPassAuth.isLoggedIn && vocPassAuth.currentUser != null) ...[
                CircleAvatar(
                  radius: 40,
                  backgroundImage: vocPassAuth.currentUser!.avatarURL != null
                      ? NetworkImage(vocPassAuth.currentUser!.avatarURL!)
                      : null,
                  child: vocPassAuth.currentUser!.avatarURL == null
                      ? const Icon(Icons.person, size: 40, color: Colors.blue)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  vocPassAuth.currentUser!.displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${vocPassAuth.currentUser!.username}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ] else ...[
                const Icon(Icons.school, size: 64, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  'VocPass',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('${AppConfig.vocPassApiHost}/auth');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('登入 VocPass 帳號'),
                ),
              ],

              const SizedBox(height: 32),

              // 出來玩
              _HomeButton(
                icon: Icons.calendar_month,
                label: '出來玩',
                color: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const W2MListScreen()),
                ),
              ),

              const SizedBox(height: 12),

              // 課表產生器
              /*
              _HomeButton(
                icon: Icons.wallpaper,
                label: '課表產生器',
                color: Colors.teal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WallpaperTemplateListScreen()),
                ),
              ),
              */

              const SizedBox(height: 12),

              // 吃啥？
              _HomeButton(
                icon: Icons.restaurant,
                label: '吃啥？',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RestaurantScreen()),
                ),
              ),

              const SizedBox(height: 12),

              // 不揪？
              _HomeButton(
                icon: Icons.people,
                label: '不揪？',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FollowingListScreen()),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
