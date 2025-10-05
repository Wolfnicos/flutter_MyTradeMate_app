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
                const Text('Strategy: Dynamic AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Switch(value: active, onChanged: (_) {}, activeColor: Colors.cyan),
              ],
            ),
            const SizedBox(height: 5),
            const Text('Status: Active. Monitoring Crypto & Stocks.', style: TextStyle(color: Colors.white70)),
            const Divider(height: 25, color: Colors.white12),
            Center(
              child: TextButton.icon(
                onPressed: onModify,
                icon: const Icon(Icons.settings, color: Colors.indigoAccent),
                label: const Text('Modify Strategy Settings', style: TextStyle(color: Colors.indigoAccent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


