import 'package:flutter/material.dart';

class AiSignalCard extends StatelessWidget {
  final double? probUp; // 0..1
  final double? nextReturn; // poate fi mic (±%)
  final double? volatility; // unități model
  final String horizon; // 5m / 15m / 1h / 1d
  const AiSignalCard({
    super.key,
    required this.probUp,
    required this.nextReturn,
    required this.volatility,
    required this.horizon,
  });

  @override
  Widget build(BuildContext context) {
    final p = probUp;
    final dir = (p == null) ? 'NEUTRAL' : (p >= 0.5 ? 'BUY' : 'SELL');
    final conf = (p == null) ? '—' : '${(p * 100).toStringAsFixed(1)}%';
    final ret = (nextReturn == null)
        ? '—'
        : '${(nextReturn! * 100).toStringAsFixed(2)}%';
    final vol = (volatility == null) ? '—' : volatility!.toStringAsFixed(4);

    final dirColor =
        p == null ? Colors.grey : (p >= 0.5 ? Colors.green : Colors.red);

    final color =
        p == null ? Colors.grey : (p >= 0.5 ? Colors.green : Colors.red);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 38),
              foregroundColor: color,
              child: Icon(p == null
                  ? Icons.insights_outlined
                  : (p >= 0.5 ? Icons.trending_up : Icons.trending_down)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Prediction ($horizon)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Direction: $dir',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: dirColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Confidence: $conf',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Expanded(
                        child: Text('Next Return: $ret',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Expanded(
                        child: Text('Volatility: $vol',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



