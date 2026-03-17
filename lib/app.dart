import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/school_selection_screen.dart';
import 'screens/unsupported_screen.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/school_config_manager.dart';
import 'theme/app_theme.dart';

class VocPassApp extends StatelessWidget {
  const VocPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocPass',
      theme: AppTheme.light(),
      home: const RootRouter(),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<CacheService, SchoolConfigManager, ApiService>(
      builder: (context, cache, schoolManager, api, _) {
        print('[vocPass-log] 測試 print');
        if (!cache.hasSeenOnboarding) {
          return const OnboardingScreen();
        }
        if (!schoolManager.hasSelectedSchool) {
          return const SchoolSelectionScreen();
        }
        if (api.isLoggedIn) {
          return const MainTabScreen();
        }
        final school = schoolManager.selectedSchool;
        final loginUrl = school?.loginUrl;
        if (school != null && loginUrl != null) {
          return LoginScreen(school: school, targetUrl: loginUrl);
        }
        return const UnsupportedScreen(
          title: '無法載入學校配置',
          message: '請重新選擇學校或稍後再試',
          showRetry: false,
        );
      },
    );
  }
}
