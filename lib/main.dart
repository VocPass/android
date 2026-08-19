import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/dynamic_island_service.dart';
import 'services/notification_token_service.dart';
import 'services/school_config_manager.dart';
import 'services/vocpass_auth_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.instance.init();
  await WidgetService.init();
  await SchoolConfigManager.instance.init();
  await VocPassAuthService.instance.init();
  final isGuest = SchoolConfigManager.instance.selectedSchool?.isGuest == true;
  if (!isGuest) {
    await VocPassAuthService.instance.restoreSession();
  }
  if (CacheService.instance.autoStartDynamicIsland) {
    await DynamicIslandService.instance.startClassStatusSync();
  } else {
    await DynamicIslandService.instance.stopClassStatusSync();
  }
  await NotificationTokenService.instance.init();
  // 每次開啟 app 都重新抓取 /school 並更新快取（不阻塞啟動）；
  // 抓完後會依學校名稱套用最新設定並通知畫面更新。
  unawaited(SchoolConfigManager.instance.loadSchools());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: CacheService.instance),
        ChangeNotifierProvider.value(value: SchoolConfigManager.instance),
        ChangeNotifierProvider.value(value: ApiService.instance),
        ChangeNotifierProvider.value(value: VocPassAuthService.instance),
      ],
      child: const VocPassApp(),
    ),
  );
}
