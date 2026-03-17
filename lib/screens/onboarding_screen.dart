import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cache_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.school,
      color: Colors.blue,
      title: '歡迎使用 VocPass',
      subtitle: '高職通用校務查詢系統',
      description: '快速查詢您的成績、課表、缺曠記錄等校務資訊',
    ),
    _OnboardingPage(
      icon: Icons.calendar_today,
      color: Colors.green,
      title: '課表查詢',
      subtitle: '隨時掌握課程安排',
      description: '查看每週課表，支援離線快取，無需每次重新載入',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart,
      color: Colors.orange,
      title: '成績查詢',
      subtitle: '學年成績與考試成績',
      description: '查看各科目成績、班級排名，追蹤學習進度',
    ),
    _OnboardingPage(
      icon: Icons.access_time,
      color: Colors.purple,
      title: '缺曠紀錄',
      subtitle: '出勤狀態一目瞭然',
      description: '查看缺曠統計、各科目出勤率，掌握出席狀況',
    ),
    _OnboardingPage(
      icon: Icons.verified_user,
      color: Colors.indigo,
      title: '隱私保護',
      subtitle: '資料僅在本地處理',
      description: '帳號密碼僅儲存在本機，不會傳送至第三方伺服器。',
    ),
    _OnboardingPage(
      icon: Icons.check_circle,
      color: Colors.cyan,
      title: '準備開始',
      subtitle: '登入您的帳號',
      description: '使用學校帳號登入後即可開始使用所有功能',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      context.read<CacheService>().hasSeenOnboarding = true;
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _OnboardingPageView(page: page),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_currentPage > 0)
                      OutlinedButton(
                        onPressed: _prevPage,
                        child: const Text('上一步'),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _nextPage,
                        child: Text(
                          _currentPage < _pages.length - 1 ? '下一步' : '開始使用',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(page.icon, size: 88, color: page.color),
        const SizedBox(height: 24),
        Text(
          page.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          page.subtitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          page.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
