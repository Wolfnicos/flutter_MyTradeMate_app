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
  final Map<String, double>? tfConfidence; // optional: per-timeframe confidence
  final String? symbol; // optional: show selected symbol on the right
  final Map<String, List<double>>? tfProbs; // optional: per-timeframe probs
  final Map<String, double>? tfExp; // per TF expReturn
  final Map<String, double>? tfVol; // per TF annVol
  final ValueChanged<String>? onSelectTf; // when user taps a TF chip
  final String? selectedTf; // currently selected TF
  const ProSignalPanel(
      {super.key,
      required this.action,
      required this.confidence,
      required this.expReturn,
      required this.annVol,
      required this.timeframe,
      this.subtitle,
      this.tsConfidence,
      this.visionConfidence,
      this.tfConfidence,
      this.symbol,
      this.tfProbs,
      this.tfExp,
      this.tfVol,
      this.onSelectTf,
      this.selectedTf});

  @override
  Widget build(BuildContext context) {
    // If a TF is selected and we have its confidence, display that instead of global
    final double effectiveConf = (selectedTf != null && tfConfidence != null && tfConfidence!.containsKey(selectedTf))
        ? (tfConfidence![selectedTf!]!.clamp(0.0, 1.0))
        : confidence.clamp(0.0, 1.0);
    final confPct = (effectiveConf * 100).clamp(0, 100).toDouble();
    // If TF selected, prefer its expReturn/vol if available
    final double effExp = (selectedTf != null && tfExp != null && tfExp!.containsKey(selectedTf))
        ? (tfExp![selectedTf!] ?? expReturn)
        : expReturn;
    final double effVol = (selectedTf != null && tfVol != null && tfVol!.containsKey(selectedTf))
        ? (tfVol![selectedTf!] ?? annVol)
        : annVol;

    // If a TF is selected, compute its effective action for the badge using same rules as chips
    String effAction = action;
    if (selectedTf != null && tfProbs != null && tfProbs!.containsKey(selectedTf)) {
      final List<double> probs = tfProbs![selectedTf!]!;
      final probBuy = probs[0];
      final probSell = probs[2];
      final dirConf = probBuy > probSell ? probBuy : probSell;
      const double confThresh = 0.66;
      const double minAbsRet = 0.006;
      // Volatility gating: if very high vol, prefer HOLD
      if (effVol > 1.0) {
        effAction = 'HOLD';
      } else if (effExp >= minAbsRet && probBuy >= confThresh) {
        effAction = 'BUY';
      } else if (-effExp >= minAbsRet && probSell >= confThresh) {
        effAction = 'SELL';
      } else if (dirConf >= 0.40) {
        effAction = probBuy >= probSell ? 'BUY' : 'SELL';
      } else {
        effAction = 'HOLD';
      }
    }
    final tfLabel = selectedTf != null
        ? selectedTf!
        : (AiConfig.useVisionVote ? 'multi (5m/15m/1h/4h/1d)' : timeframe);
    final modelLabel = AiConfig.useVisionVote ? 'PatchTST+Vision' : 'PatchTST';
    final subtitleText = 'Model: $modelLabel · TF: $tfLabel · Rev: ${AiConfig.modelRev}';
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
                ActionBadge(action: effAction),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(subtitleText,
                      style: const TextStyle(color: kText2, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                if (symbol != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(symbol!,
                        style: const TextStyle(
                            color: kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
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
                value: confPct / 100.0, color: _colorForAction(effAction)),
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
                  Text('${(effExp * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(
                          color: kText, fontWeight: FontWeight.w700)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Volatility',
                      style: TextStyle(color: kText2, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${(effVol * 100).toStringAsFixed(1)}%',
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
            if (tfProbs != null && tfProbs!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('TF breakdown',
                  style: TextStyle(color: kText2, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildTfActionChips(),
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

  List<Widget> _buildTfActionChips() {
    if (tfProbs == null) return const <Widget>[];
    final List<String> order = const ['5m','15m','1h','4h','1d'];
    final entries = tfProbs!.entries.toList()
      ..sort((a,b){
        final ia = order.indexOf(a.key);
        final ib = order.indexOf(b.key);
        return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
      });
    return entries.map((e){
      final probs = e.value;
      // Decide per TF cu aceleași praguri ca engine: folosim expReturn/vol dacă disponibile
      final er = tfExp != null ? (tfExp![e.key] ?? 0.0) : 0.0;
      final vol = tfVol != null ? (tfVol![e.key] ?? 0.0) : annVol;
      String a = 'HOLD';
      final probBuy = probs[0];
      final probSell = probs[2];
      final dirConf = probBuy > probSell ? probBuy : probSell;
      const double confThresh = 0.66; // match AiConfig.probBuy/Sell default
      const double minAbsRet = 0.006; // 0.6%
      if (vol <= 1.0 && dirConf >= 0.40) {
        if (er >= minAbsRet && probBuy >= confThresh) a = 'BUY';
        else if (- er >= minAbsRet && probSell >= confThresh) a = 'SELL';
        else a = probBuy >= probSell ? 'BUY' : 'SELL';
      }
      final color = _colorForAction(a);
      final bool isSelected = selectedTf != null && selectedTf == e.key;
      final chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.22) : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isSelected ? 0.8 : 0.5)),
        ),
        child: Text('${e.key} $a',
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      );
      if (onSelectTf != null) {
        return InkWell(onTap: () => onSelectTf!(e.key), child: chip);
      }
      return chip;
    }).toList();
  }
}
