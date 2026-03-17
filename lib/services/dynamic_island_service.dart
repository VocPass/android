import 'dart:io';

import 'package:flutter/services.dart';

class DynamicIslandService {
  DynamicIslandService._internal();

  static final DynamicIslandService instance = DynamicIslandService._internal();

  static const MethodChannel _channel = MethodChannel('vocpass/dynamic_island');

  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
