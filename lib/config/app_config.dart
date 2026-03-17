import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get isDebugBuild => kDebugMode;

  static String get vocPassApiHost =>
      isDebugBuild ? 'https://vocpass.com' : 'https://vocpass.com';
}
