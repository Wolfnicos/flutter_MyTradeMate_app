import 'package:flutter/material.dart';

enum SignalDir { up, down, neutral }

class SignalBadge extends StatelessWidget {
  final SignalDir dir;
  const SignalBadge({super.key, required this.dir});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (dir) {
      case SignalDir.up:
        color = Colors.green;
        text = 'UP';
        break;
      case SignalDir.down:
        color = Colors.red;
        text = 'DOWN';
        break;
      case SignalDir.neutral:
      default:
        color = Theme.of(context).colorScheme.outline;
        text = '-';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(.18),
        border: Border.all(color: color.withOpacity(.6)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }
}




