import 'package:flutter/material.dart';
import '../../widgets/premium_widgets.dart';
import '../../ai/ai_config.dart';

class ProSignalPanel extends StatelessWidget {
  final String action; // BUY/SELL/HOLD
  final double confidence; // 0..1
  final double expReturn; // % fraction
  final double annVol; // % fraction
  final String timeframe;
  final String? subtitle; // e.g., Model missing for SYMBOL/TF
  const ProSignalPanel(
      {super.key,
      required this.action,
      required this.confidence,
      required this.expReturn,
      required this.annVol,
      required this.timeframe,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    final confPct = (confidence * 100).clamp(0, 100).toDouble();
    final subtitleText = 'Model: PatchTST${AiConfig.useVisionVote ? "+Vision" : ""} · TF: $timeframe · Rev: ${AiConfig.modelRev}';
    return ModernCard(
      hasGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ActionBadge(action: action),
              const SizedBox(width: 12),
              Expanded(
                child: Text(subtitleText,
                    style: const TextStyle(color: kText2, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Visibility(
                visible: AiConfig.useVisionVote,
                child: Chip(
                  label: const Text('Vision ✓'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(color: kText2, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          const Text('Confidence',
              style: TextStyle(color: kText2, fontSize: 12)),
          const SizedBox(height: 6),
          NeonProgressBar(
              value: confPct / 100.0, color: _colorForAction(action)),
          const SizedBox(height: 6),
          Text('${confPct.toStringAsFixed(1)}%',
              style:
                  const TextStyle(color: kText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Expected Return',
                    style: TextStyle(color: kText2, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${(expReturn * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(
                        color: kText, fontWeight: FontWeight.w700)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Volatility',
                    style: TextStyle(color: kText2, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${(annVol * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: kText, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  static Color _colorForAction(String a) {
    switch (a.toUpperCase()) {
      case 'BUY':
        return kBuy;
      case 'SELL':
        return kSell;
      default:
        return kHold;
    }
  }
}
