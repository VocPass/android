import 'package:flutter/material.dart';

class CaptchaIndicator extends StatelessWidget {
  final bool isRecognizing;
  final String? lastText;

  const CaptchaIndicator({
    super.key,
    required this.isRecognizing,
    required this.lastText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: isRecognizing || (lastText != null && lastText!.isNotEmpty) ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecognizing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              isRecognizing
                  ? '驗證碼辨識中...'
                  : '識別結果：${lastText ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
