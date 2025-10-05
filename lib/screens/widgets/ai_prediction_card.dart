import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import 'package:mytrademate/ui/explain_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AIPredictionCard extends StatefulWidget {
  final String symbol;
  const AIPredictionCard({super.key, required this.symbol});

  @override
  State<AIPredictionCard> createState() => _AIPredictionCardState();
}

class _AIPredictionCardState extends State<AIPredictionCard> {
  bool _showUncertainty = true;
  bool _showGaps = true;

  Future<void> _openModelCard() async {
    final uri = Uri.parse('https://github.com/lupudragos/mytrademate/blob/main/ModelCard.md');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AIPrediction>(
      future: AIService().getPrediction(widget.symbol),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('AI unavailable (model load failed). Trading & price still work.' + (snapshot.error != null ? ' ${snapshot.error}' : ''))),
              ]),
            ),
          );
        }
        final p = snapshot.data!;
        final actionColor = p.action == 'BUY' ? Colors.green : p.action == 'SELL' ? Colors.red : Colors.amber;
        final actionIcon = p.action == 'BUY' ? Icons.trending_up : (p.action == 'SELL' ? Icons.trending_down : Icons.pause_circle_outline);
        return Card(
          elevation: 6,
          color: Theme.of(context).cardColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: actionColor.withOpacity(0.5), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alpha AI Prediction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: actionColor)),
                    Icon(actionIcon, color: actionColor, size: 28),
                  ],
                ),
                const Divider(height: 20, color: Colors.white12),
                Row(
                  children: [
                    const Text('Action:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    Text(p.action, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: actionColor)),
                    const Spacer(),
                    _buildConfidenceIndicator(p.confidence),
                  ],
                ),
                const SizedBox(height: 15),
                _buildPredictionRow('Target Price (24h):', '\$${p.targetPrice.toStringAsFixed(2)}', Icons.price_change, Colors.cyanAccent),
                _buildPredictionRow('Predicted Volatility:', p.volatility, Icons.scatter_plot, Colors.orangeAccent),
                const SizedBox(height: 15),
                // Why this signal? — simple, safe explanation with toggles
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.white10),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline, color: Colors.indigoAccent),
                    title: const Text('Why this signal?', style: TextStyle(color: Colors.white)),
                    children: [
                      const SizedBox(height: 8),
                      Text(_plainLanguageWhy(p), style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.indigoAccent,
                        title: const Text('Show uncertainty note', style: TextStyle(color: Colors.white70)),
                        value: _showUncertainty,
                        onChanged: (v) => setState(() => _showUncertainty = v),
                      ),
                      if (_showUncertainty)
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, bottom: 8),
                          child: Text(
                            'This is probabilistic and may be wrong. Confidence < 60% means higher uncertainty.',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.indigoAccent,
                        title: const Text('Show data gaps note', style: TextStyle(color: Colors.white70)),
                        value: _showGaps,
                        onChanged: (v) => setState(() => _showGaps = v),
                      ),
                      if (_showGaps)
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, bottom: 8),
                          child: Text(
                            'If recent candles are missing, the model uses a fallback; treat the signal with extra care.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _openModelCard,
                          icon: const Icon(Icons.description, color: Colors.indigoAccent),
                          label: const Text('Read Model Card', style: TextStyle(color: Colors.indigoAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      // Build a minimal features sequence; in a fuller version, fetch actual 64×N
                      final seq = List.generate(64, (_) => [p.targetPrice, p.confidence, 0.0]);
                      final data = mapToExplain(widget.symbol, seq, p);
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExplainPage(data: data)));
                    },
                    icon: const Icon(Icons.info_outline, color: Colors.indigoAccent),
                    label: const Text('Why this prediction? (AI Justification)', style: TextStyle(color: Colors.indigoAccent)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildConfidenceIndicator(double confidence) {
  Color confidenceColor;
  if (confidence >= 80) {
    confidenceColor = Colors.greenAccent;
  } else if (confidence >= 60) {
    confidenceColor = Colors.yellowAccent;
  } else {
    confidenceColor = Colors.redAccent;
  }

  return Column(
    children: [
      const Text('Confidence', style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 4),
      Text('${confidence.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: confidenceColor)),
    ],
  );
}

Widget _buildPredictionRow(String label, String value, IconData icon, Color iconColor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5.0),
    child: Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    ),
  );
}


String _plainLanguageWhy(AIPrediction p) {
  final dir = p.action == 'BUY' ? '↑' : (p.action == 'SELL' ? '↓' : '—');
  final volNote = p.volatility == 'HIGH'
      ? 'higher volatility'
      : (p.volatility == 'MEDIUM' ? 'moderate volatility' : 'lower volatility');
  final conf = p.confidence;
  // Keep wording cautious and generic
  return 'We predict $dir price tendency with $volNote in the next period. '
         'This is based on recent price dynamics and volatility estimates. '
         'Confidence ${conf.toStringAsFixed(0)}%. Treat as guidance, not advice.';
}


