import 'package:flutter/material.dart';

class AIStatusCard extends StatelessWidget {
  final bool active;
  final VoidCallback? onModify;
  const AIStatusCard({super.key, this.active = true, this.onModify});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strategy: Crypto AI',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('TensorFlow Lite • 3 Models',
                        style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
                Switch(
                    value: active, onChanged: (_) {}, activeThumbColor: Colors.cyan),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text('Active • Monitoring 15+ Crypto Pairs',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '🎯 Direction Model: Predicts BUY/SELL/HOLD signals\n'
              '💰 Return Model: Estimates next-period returns\n'
              '📊 Volatility Model: Calculates market risk levels',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Divider(height: 25, color: Colors.white12),
            Center(
              child: TextButton.icon(
                onPressed: onModify,
                icon: const Icon(Icons.settings, color: Colors.indigoAccent),
                label: const Text('Modify Strategy Settings',
                    style: TextStyle(color: Colors.indigoAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


