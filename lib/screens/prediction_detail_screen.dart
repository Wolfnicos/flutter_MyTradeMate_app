import 'package:flutter/material.dart';
import 'package:mytrademate/ai/entities.dart' as ai;
import 'package:mytrademate/ai/ai_locator.dart';

class PredictionDetailScreen extends StatefulWidget {
  final String symbol;
  final dynamic prediction; // ai.Prediction sau alt payload compatibil
  const PredictionDetailScreen({super.key, required this.symbol, required this.prediction});

  @override
  State<PredictionDetailScreen> createState() => _PredictionDetailScreenState();
}

class _PredictionDetailScreenState extends State<PredictionDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // Normalizează valorile din payload la format unitar
    final _NormalizedPred np = _normalize(widget.prediction, widget.symbol);

    final String action = np.action;
    final double confidencePct = np.confidencePercent;
    final double expReturnPct = np.expReturnPercent;
    final double volPct = np.annVolPercent;
    final int directionProb = np.directionProbabilityPercent;

    final Color headerColor = action == 'BUY'
        ? Colors.green
        : (action == 'SELL' ? Colors.red : Colors.grey);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} Analysis'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: headerColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(widget.symbol.replaceAll('USDT', '/USDT'),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: headerColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [Icon(Icons.psychology, color: Colors.blue), SizedBox(width: 8), Text('AI Confidence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: confidencePct / 100.0, backgroundColor: Colors.grey[800], color: Colors.blue, minHeight: 8),
                const SizedBox(height: 8),
                Text('${confidencePct.toStringAsFixed(1)}% Confidence', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(_getConfidenceExplanation(confidencePct), style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [Icon(Icons.auto_graph, color: Colors.orange), SizedBox(width: 8), Text('Model Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 16),
                _buildModelRow('📈 Direction Model', 'Predicts $action with ${directionProb}% probability', 'Analyzed 64 candles of price action patterns'),
                const Divider(height: 24),
                _buildModelRow('💰 Return Model', 'Expected return: ${expReturnPct >= 0 ? '+' : ''}${expReturnPct.toStringAsFixed(2)}%', 'Based on historical momentum and trend strength'),
                const Divider(height: 24),
                _buildModelRow('📊 Volatility Model', 'Market volatility: ${volPct.toStringAsFixed(1)}%', 'Risk level: ${_getRiskLevel(volPct)}'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [Icon(Icons.analytics, color: Colors.green), SizedBox(width: 8), Text('Technical Signals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 16),
                _buildIndicatorRow('Trend', _getTrendSignal(expReturnPct)),
                _buildIndicatorRow('Momentum', _getMomentumSignal(confidencePct)),
                _buildIndicatorRow('Volatility', _getVolatilitySignal(volPct)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Icon(Icons.warning_amber, color: Colors.orange), const SizedBox(width: 12), Expanded(child: Text('This is an AI prediction, not financial advice. Always do your own research.', style: TextStyle(fontSize: 13, color: Colors.grey)))]),
          ),
        ],
      ),
    );
  }

  Widget _buildModelRow(String title, String value, String description) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 15)), const SizedBox(height: 4), Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }

  Widget _buildIndicatorRow(String label, String signal) {
    Color color = signal.contains('Bullish') || signal.contains('Positive') ? Colors.green : signal.contains('Bearish') || signal.contains('Negative') ? Colors.red : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 15)), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(signal, style: TextStyle(color: color, fontWeight: FontWeight.w600))) ]),
    );
  }

  String _getConfidenceExplanation(double conf) {
    if (conf >= 50) return 'Strong signal - High probability of accurate prediction';
    if (conf >= 35) return 'Moderate signal - Reasonable confidence in prediction';
    if (conf >= 20) return 'Weak signal - Lower confidence, trade with caution';
    return 'Very weak signal - Consider waiting for better setup';
  }

  String _getRiskLevel(double vol) {
    if (vol < 2) return 'Low';
    if (vol < 5) return 'Medium';
    return 'High';
  }

  String _getTrendSignal(double ret) {
    if (ret > 2) return 'Strong Bullish';
    if (ret > 0) return 'Bullish';
    if (ret > -2) return 'Bearish';
    return 'Strong Bearish';
  }

  String _getMomentumSignal(double conf) {
    return conf > 40 ? 'Positive' : conf > 25 ? 'Neutral' : 'Negative';
  }

  String _getVolatilitySignal(double vol) {
    return vol < 3 ? 'Low' : vol < 6 ? 'Medium' : 'High';
  }
}

class _NormalizedPred {
  final String action;
  final double confidencePercent;
  final double expReturnPercent;
  final double annVolPercent;
  final int directionProbabilityPercent;
  _NormalizedPred({
    required this.action,
    required this.confidencePercent,
    required this.expReturnPercent,
    required this.annVolPercent,
    required this.directionProbabilityPercent,
  });
}

_NormalizedPred _normalize(dynamic pred, String symbol) {
  if (pred is ai.Prediction) {
    final String action = AILocator.I.decide(pred);
    final double confPct = pred.confidencePercent;
    final double expPct = pred.expReturnPercent;
    final double volPct = pred.annVolPercent;
    // Derivă prob direcțională
    final int dirProb = () {
      if (action == 'BUY') return (pred.pBuy * 100).round();
      if (action == 'SELL') return ((1.0 - pred.pBuy - (pred.pHold ?? 0.0)) * 100).round();
      // HOLD
      final hold = (pred.pHold ?? (1.0 - pred.pBuy - 0.0));
      return (hold * 100).round();
    }();
    return _NormalizedPred(
      action: action,
      confidencePercent: confPct,
      expReturnPercent: expPct,
      annVolPercent: volPct,
      directionProbabilityPercent: dirProb,
    );
  }

  // Fallback generic dynamic shape
  try {
    final String action = (pred.action ?? 'HOLD').toString().toUpperCase();
    double conf = (pred.confidence ?? 0.0).toDouble();
    if (conf <= 1.2) conf *= 100.0; // permite și [0,1]
    double exp = (pred.expReturn ?? 0.0).toDouble();
    // Dacă pare fracțional mic, tratează ca % deja
    double vol = (pred.volatility ?? 0.0).toDouble();
    final List probs = (pred.probs ?? const [33, 33, 33]);
    int dirProb = 0;
    if (action == 'BUY') dirProb = (probs[0] as num).round();
    else if (action == 'SELL') dirProb = (probs[2] as num).round();
    else dirProb = (probs[1] as num).round();
    return _NormalizedPred(
      action: action,
      confidencePercent: conf,
      expReturnPercent: exp,
      annVolPercent: vol,
      directionProbabilityPercent: dirProb,
    );
  } catch (_) {
    return _NormalizedPred(action: 'HOLD', confidencePercent: 0, expReturnPercent: 0, annVolPercent: 0, directionProbabilityPercent: 33);
  }
}


