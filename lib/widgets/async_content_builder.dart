import 'package:flutter/material.dart';

import '../screens/unsupported_screen.dart';

class AsyncContentBuilder extends StatelessWidget {
  final bool isLoading;
  final bool isUnsupported;
  final String? error;
  final VoidCallback? onRetry;
  final Widget child;

  const AsyncContentBuilder({
    super.key,
    required this.isLoading,
    this.isUnsupported = false,
    this.error,
    this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isUnsupported) {
      return const UnsupportedScreen(
        title: '此功能不支援',
        message: '目前選擇的學校尚未支援此功能',
      );
    }
    if (error != null) {
      return UnsupportedScreen(
        title: '載入失敗',
        message: error!,
        onRetry: onRetry,
      );
    }
    return child;
  }
}
