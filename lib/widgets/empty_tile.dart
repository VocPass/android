import 'package:flutter/material.dart';

class EmptyTile extends StatelessWidget {
  final String message;

  const EmptyTile({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
