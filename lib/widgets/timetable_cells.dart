import 'package:flutter/material.dart';

class TimetableHeaderCell extends StatelessWidget {
  final String text;

  const TimetableHeaderCell({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class TimetablePeriodCell extends StatelessWidget {
  final String text;

  const TimetablePeriodCell({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
