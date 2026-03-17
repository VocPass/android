import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/school_config_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.instance.init();
  await SchoolConfigManager.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: CacheService.instance),
        ChangeNotifierProvider.value(value: SchoolConfigManager.instance),
        ChangeNotifierProvider.value(value: ApiService.instance),
      ],
      child: const VocPassApp(),
    ),
  );
}
