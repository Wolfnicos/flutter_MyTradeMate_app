import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import 'package:mytrademate/ui/explain_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/semantics.dart';
import '../../core/explain/explanation_builder.dart';

class AIPredictionCard extends StatefulWidget {
  final String symbol;
  const AIPredictionCard({super.key, required this.symbol});

  @override
  State<AIPredictionCard> createState() => _AIPredictionCardState();
}

class _AIPredictionCardState extends State<AIPredictionCard> {
  // persistență toggles
  static const _kShowUncertainty = 'ai.show_uncertainty_note';
  static const _kShowDataGaps = 'ai.show_data_gaps_note';

  bool _showUncertainty = true;
  bool _showGaps = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showUncertainty = p.getBool(_kShowUncertainty) ?? true;
      _showGaps = p.getBool(_kShowDataGaps) ?? true;
      _prefsLoaded = true;
    });
  }

  Future<void> _setShowUncertainty(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowUncertainty, v);
    if (!mounted) return;
    setState(() => _showUncertainty = v);
  }

  Future<void> _setShowDataGaps(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowDataGaps, v);
    if (!mounted) return;
    setState(() => _showGaps = v);
  }

  Future<void> _openModelCard() async {
    final uri = Uri.parse('https://github.com/lupudragos/mytrademate/blob/main/ModelCard.md');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open model card')),
      );
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

        // Build safe explanation input (fallbacks where data not available)
        Direction dir = Direction.flat;
        if (p.action == 'BUY') dir = Direction.up; else if (p.action == 'SELL') dir = Direction.down;
        VolLevel vol = VolLevel.moderate;
        final vLbl = p.volatility.toUpperCase();
        if (vLbl == 'LOW') vol = VolLevel.low; else if (vLbl == 'HIGH') vol = VolLevel.high;
        final bool isPaperMode = const bool.fromEnvironment('PAPER_TRADING', defaultValue: false);
        final expIn = ExplanationInput(
          direction: dir,
          volLevel: vol,
          confidence: p.probUp, // 0..1
          topFactors: const <String>[],
          dataGaps: false,
          lastTickAge: Duration.zero,
          isPaperMode: isPaperMode,
        );
        final expOut = ExplanationBuilder.build(expIn);
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
                      Semantics(
                        label: 'Why this signal panel',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Why this signal?', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                if (isPaperMode)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                    ),
                                    child: const Text('PAPER / TESTNET', style: TextStyle(fontSize: 11)),
                                  ),
                                const Spacer(),
                                InkWell(
                                  onTap: _openModelCard,
                                  child: Semantics(
                                    button: true,
                                    label: 'Open model card',
                                    hint: 'Opens the model card in your browser',
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Text('Model card →', style: TextStyle(decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(expOut.headline, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(expOut.details, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            if (_prefsLoaded && _showUncertainty && (expOut.uncertainty?.isNotEmpty ?? false))
                              _WarnLine(text: expOut.uncertainty!),
                            if (_prefsLoaded && _showGaps && (expOut.dataGap?.isNotEmpty ?? false))
                              _WarnLine(text: expOut.dataGap!),
                            const SizedBox(height: 8),
                            Text(expOut.advisory, style: Theme.of(context).textTheme.bodySmall),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    value: _showUncertainty,
                                    onChanged: _setShowUncertainty,
                                    title: const Text('Show uncertainty note'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: SwitchListTile(
                                    value: _showGaps,
                                    onChanged: _setShowDataGaps,
                                    title: const Text('Show data gaps note'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
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

class _WarnLine extends StatelessWidget {
  final String text;
  const _WarnLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.amberAccent),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}


