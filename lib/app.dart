import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_tab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/school_selection_screen.dart';
import 'services/cache_service.dart';
import 'services/school_config_manager.dart';
import 'services/vocpass_auth_service.dart';
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

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link (app opened via deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      if (kDebugMode) print('[DeepLink] getInitialLink error: $e');
    }

    // Listen for subsequent links (app already running)
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) {
        if (kDebugMode) print('[DeepLink] stream error: $e');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) print('[DeepLink] Received: $uri');

    // vocpass://callback?token=xxx
    if (uri.scheme == 'vocpass') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) print('[DeepLink] Got token, logging in...');
        VocPassAuthService.instance.handleTokenLogin(token);
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CacheService, SchoolConfigManager>(
      builder: (context, cache, schoolManager, _) {
        if (!cache.hasSeenOnboarding) {
          return const OnboardingScreen();
        }
        if (!schoolManager.hasSelectedSchool) {
          return const SchoolSelectionScreen();
        }
        return const MainTabScreen();
      },
    );
  }
}
