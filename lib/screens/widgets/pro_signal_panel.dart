import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../widgets/premium_widgets.dart';
import '../../ai/ai_config.dart';
import '../vision_debug_screen.dart';

class ProSignalPanel extends StatelessWidget {
  final String action; // BUY/SELL/HOLD
  final double confidence; // 0..1
  final double expReturn; // % fraction
  final double annVol; // % fraction
  final String timeframe;
  final String? subtitle; // e.g., Model missing for SYMBOL/TF
  final double? tsConfidence; // optional: confidence from TS-only
  final double? visionConfidence; // optional: confidence from Vision-only
  const ProSignalPanel(
      {super.key,
      required this.action,
      required this.confidence,
      required this.expReturn,
      required this.annVol,
      required this.timeframe,
      this.subtitle,
      this.tsConfidence,
      this.visionConfidence});

  @override
  Widget build(BuildContext context) {
    final confPct = (confidence * 100).clamp(0, 100).toDouble();
    final subtitleText = AiConfig.useVisionVote
        ? 'Model: PatchTST+Vision · TF: multi (5m/15m/1h/4h/1d) · Rev: ${AiConfig.modelRev}'
        : 'Model: PatchTST · TF: $timeframe · Rev: ${AiConfig.modelRev}';
    return GestureDetector(
      onLongPress: kDebugMode
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisionDebugScreen()),
              );
            }
          : null,
      child: ModernCard(
      hasGlow: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (tsConfidence != null || visionConfidence != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (tsConfidence != null) ...[
                    const Icon(Icons.show_chart, size: 16, color: kText2),
                    const SizedBox(width: 6),
                    Text('TS conf: ${(tsConfidence! * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: kText2, fontSize: 12)),
                  ],
                  if (tsConfidence != null && visionConfidence != null)
                    const SizedBox(width: 16),
                  if (visionConfidence != null) ...[
                    const Icon(Icons.remove_red_eye, size: 16, color: kText2),
                    const SizedBox(width: 6),
                    Text('Vision conf: ${(visionConfidence! * 100).toStringAsFixed(1)}% ',
                        style: const TextStyle(color: kText2, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ));
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
