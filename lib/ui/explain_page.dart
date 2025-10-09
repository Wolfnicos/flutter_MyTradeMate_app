import 'package:flutter/material.dart';
import 'package:mytrademate/ai/explain.dart';
// Uses ExplainData type from legacy AI service; page remains as-is for explain rendering.

class ExplainPage extends StatelessWidget {
  final ExplainData data;
  const ExplainPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Explain ${data.symbol}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prob↑: ${(data.probUp * 100).toStringAsFixed(2)}%'),
            Text('Next return: ${(data.nextReturn * 100).toStringAsFixed(2)}%'),
            Text(
                'Volatility: ${(data.volatility * 100).toStringAsFixed(2)}% (${data.volatilityLabel})'),
            const SizedBox(height: 12),
            const Text('Features (64×N) sample:'),
            Expanded(
              child: ListView.builder(
                itemCount: data.features.length,
                itemBuilder: (_, i) => Text(
                  data.features[i]
                      .take(6)
                      .map((e) => e.toStringAsFixed(4))
                      .join(', '),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
