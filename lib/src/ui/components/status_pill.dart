import 'package:flutter/material.dart';

enum StatusLevel { ok, warn, error }

class StatusPill extends StatelessWidget {
  final String text;
  final StatusLevel level;
  const StatusPill({super.key, required this.text, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      StatusLevel.ok => Colors.green,
      StatusLevel.warn => Colors.orange,
      StatusLevel.error => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 31),
        border: Border.all(color: color.withValues(alpha: 128)),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }
}



