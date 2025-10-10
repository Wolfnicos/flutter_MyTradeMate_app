import 'package:flutter/material.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/entities.dart' as ai;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/explain/explanation_builder.dart';
import 'package:mytrademate/l10n/strings.dart';
import 'package:mytrademate/core/errors.dart';
import 'package:mytrademate/ui/kit/ui_error_banner.dart';

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
    final uri = Uri.parse(
        'https://github.com/lupudragos/mytrademate/blob/main/ModelCard.md');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open model card')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ai.Prediction?>(
      future: AILocator.I.getPrediction(widget.symbol),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 140, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          final mapped = ErrorMapper.map(snapshot.error);
          // Build a safe, generic explanation for the error case
          const bool isPaperMode =
              bool.fromEnvironment('PAPER_TRADING', defaultValue: false);
          final expIn = ExplanationInput(
            direction: Direction.flat,
            volLevel: VolLevel.moderate,
            confidence: null,
            topFactors: const <String>[],
            dataGaps: false,
            lastTickAge: Duration.zero,
            isPaperMode: isPaperMode,
          );
          final expOut = ExplanationBuilder.build(expIn);
          return UiErrorBanner(
            message: 'AI prediction unavailable',
            onRetry: () => setState(() {}),
          );
          /* return Card(
            elevation: 6,
            color: Theme.of(context).cardColor.withValues(alpha: 230),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.orange.withValues(alpha: 128), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // inline,
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.white10),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: const Icon(Icons.help_outline,
                          color: Colors.indigoAccent),
                      title: Text(L10n.signalWhy,
                          style: const TextStyle(color: Colors.white)),
                      children: [
                        Semantics(
                          label: 'Why this signal panel',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(L10n.signalWhy,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  if (isPaperMode)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      child: Text(L10n.paperBadge,
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: _openModelCard,
                                    child: Semantics(
                                      button: true,
                                      label: L10n.modelCardOpenLabel,
                                      hint: L10n.modelCardOpenHint,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Text('Model card →',
                                            style: TextStyle(
                                                decoration:
                                                    TextDecoration.underline)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(expOut.headline,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text(expOut.details,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              if (_prefsLoaded &&
                                  _showUncertainty &&
                                  (expOut.uncertainty?.isNotEmpty ?? false))
                                _WarnLine(text: expOut.uncertainty!),
                              if (_prefsLoaded &&
                                  _showGaps &&
                                  (expOut.dataGap?.isNotEmpty ?? false))
                                _WarnLine(text: expOut.dataGap!),
                              const SizedBox(height: 8),
                              Text(expOut.advisory,
                                  style: Theme.of(context).textTheme.bodySmall),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      value: _showUncertainty,
                                      onChanged: _setShowUncertainty,
                                      title: Text(L10n.showUncertaintyNote),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: SwitchListTile(
                                      value: _showGaps,
                                      onChanged: _setShowDataGaps,
                                      title: Text(L10n.showDataGapsNote),
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
                ],
              ),
            ),
          ); */
        }
        final pred = snapshot.data!;
        final action = AILocator.I.decide(pred);
        final cs = Theme.of(context).colorScheme;
        final actionColor = action == 'BUY'
            ? (cs.tertiary)
            : action == 'SELL'
                ? (cs.error)
                : (cs.secondary);
        final actionIcon = action == 'BUY'
            ? Icons.trending_up
            : (action == 'SELL'
                ? Icons.trending_down
                : Icons.pause_circle_outline);

        // Build safe explanation input (fallbacks where data not available)
        Direction dir = Direction.flat;
        if (action == 'BUY') {
          dir = Direction.up;
        } else if (action == 'SELL') {
          dir = Direction.down;
        }
        VolLevel vol = VolLevel.moderate;
        final annVol = pred.annVol.abs();
        final vLbl = annVol >= 0.10
            ? 'HIGH'
            : (annVol >= 0.03 ? 'MEDIUM' : 'LOW');
        if (vLbl == 'LOW') {
          vol = VolLevel.low;
        } else if (vLbl == 'HIGH') {
          vol = VolLevel.high;
        }
        const bool isPaperMode =
            bool.fromEnvironment('PAPER_TRADING', defaultValue: false);
        final expIn = ExplanationInput(
          direction: dir,
          volLevel: vol,
          confidence: pred.pBuy, // 0..1
          topFactors: const <String>[],
          dataGaps: false,
          lastTickAge: Duration.zero,
          isPaperMode: isPaperMode,
        );
        final expOut = ExplanationBuilder.build(expIn);
        return Card(
          elevation: 6,
          color: Theme.of(context).cardColor.withValues(alpha: 230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: actionColor.withValues(alpha: 128), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MyTradeMate AI Prediction',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: actionColor)),
                    Icon(actionIcon, color: actionColor, size: 28),
                  ],
                ),
                const Divider(height: 20, color: Colors.white12),
                
                // Action and Confidence
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Action:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(action,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: actionColor)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Confidence', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${(pred.confidence()*100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: actionColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Detailed metrics grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildMetricRow('Expected Return', '${(pred.expReturn * 100).toStringAsFixed(2)}%', Icons.account_balance_wallet),
                      const Divider(height: 16, color: Colors.white12),
                      _buildMetricRow('Volatility (ann.)', '${(pred.annVol * 100).toStringAsFixed(1)}%', Icons.show_chart),
                      const Divider(height: 16, color: Colors.white12),
                      _buildMetricRow('Probability Up', '${(pred.pBuy * 100).toStringAsFixed(1)}%', Icons.trending_up),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Why this signal? — simple, safe explanation with toggles
                Theme(
                  data:
                      Theme.of(context).copyWith(dividerColor: Colors.white10),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline,
                        color: Colors.indigoAccent),
                    title: Text(L10n.signalWhy,
                        style: const TextStyle(color: Colors.white)),
                    children: [
                      Semantics(
                        label: 'Why this signal panel',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(L10n.signalWhy,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                if (isPaperMode)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                    ),
                                    child: Text(L10n.paperBadge,
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                const Spacer(),
                                InkWell(
                                  onTap: _openModelCard,
                                  child: Semantics(
                                    button: true,
                                    label: L10n.modelCardOpenLabel,
                                    hint: L10n.modelCardOpenHint,
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Text('Model card →',
                                          style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(expOut.headline,
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 4),
                            Text(expOut.details,
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            if (_prefsLoaded &&
                                _showUncertainty &&
                                (expOut.uncertainty?.isNotEmpty ?? false))
                              _WarnLine(text: expOut.uncertainty!),
                            if (_prefsLoaded &&
                                _showGaps &&
                                (expOut.dataGap?.isNotEmpty ?? false))
                              _WarnLine(text: expOut.dataGap!),
                            const SizedBox(height: 8),
                            Text(expOut.advisory,
                                style: Theme.of(context).textTheme.bodySmall),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    value: _showUncertainty,
                                    onChanged: _setShowUncertainty,
                                    title: Text(L10n.showUncertaintyNote),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: SwitchListTile(
                                    value: _showGaps,
                                    onChanged: _setShowDataGaps,
                                    title: Text(L10n.showDataGapsNote),
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
                // (Optional) Explain button removed for consistency; can be reintroduced
                // using a unified ExplainData mapped from ai.Prediction in the future.
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
      const Text('Confidence',
          style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 4),
      Text('${confidence.toStringAsFixed(1)}%',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: confidenceColor)),
    ],
  );
}

Widget _buildPredictionRow(
    String label, String value, IconData icon, Color iconColor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5.0),
    child: Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    ),
  );
}

Widget _buildMetricRow(String label, String value, IconData icon) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
      Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white)),
    ],
  );
}

// (removed legacy plain-language generator that depended on legacy AIPrediction)

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
          Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
