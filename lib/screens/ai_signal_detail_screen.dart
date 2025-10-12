import 'package:flutter/material.dart';

class AISignalDetailScreen extends StatelessWidget {
  final String symbol;
  final String action;
  final double confidence;
  final double expReturn;
  final double volatility;

  const AISignalDetailScreen({
    super.key,
    required this.symbol,
    required this.action,
    required this.confidence,
    required this.expReturn,
    required this.volatility,
  });

  @override
  Widget build(BuildContext context) {
    final isHighConfidence = confidence >= 50;
    final isLowConfidence = confidence < 35;

    return Scaffold(
      appBar: AppBar(
        title: Text('$symbol AI Signal'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Signal Header
          Card(
            color: action == 'BUY'
                ? Colors.green.withOpacity(0.1)
                : action == 'SELL'
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    symbol,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: action == 'BUY'
                          ? Colors.green
                          : action == 'SELL'
                              ? Colors.red
                              : Colors.purple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'AI SUGGESTS: $action',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Confidence Warning
          if (isLowConfidence)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ LOW CONFIDENCE SIGNAL\nWin rate typically <25% at this confidence level',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ),
            )
          else if (!isHighConfidence)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ MODERATE CONFIDENCE\nHistorical win rate ~30-40% at this level',
                      style: TextStyle(color: Colors.orange.shade300),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // AI Analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    'Confidence',
                    '${confidence.toStringAsFixed(1)}%',
                    Icons.psychology,
                    Colors.blue,
                  ),
                  _buildMetricRow(
                    'Expected Return',
                    '${expReturn >= 0 ? '+' : ''}${expReturn.toStringAsFixed(2)}%',
                    Icons.trending_up,
                    expReturn >= 0 ? Colors.green : Colors.red,
                  ),
                  _buildMetricRow(
                    'Volatility',
                    '${volatility.toStringAsFixed(1)}%',
                    Icons.show_chart,
                    volatility > 5 ? Colors.orange : Colors.blue,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Educational Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Why this signal?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getSignalExplanation(
                        action, confidence, expReturn, volatility),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Manual Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Ignore Signal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _showManualTradeDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        action == 'BUY' ? Colors.green : Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Execute $action Manually'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Risk Disclaimer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '⚠️ RISK DISCLAIMER: This AI model has a 30% historical win rate. Signals are provided for educational and analytical purposes only. Always do your own research and never invest more than you can afford to lose.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getSignalExplanation(
      String action, double conf, double ret, double vol) {
    String explanation =
        'The AI model analyzed 64 candles of price action and ';

    if (action == 'BUY') {
      explanation += 'detected bullish patterns suggesting an upward move. ';
    } else if (action == 'SELL') {
      explanation += 'detected bearish patterns suggesting a downward move. ';
    } else {
      explanation += 'found no strong directional bias. ';
    }

    if (conf < 35) {
      explanation +=
          '\n\nHowever, the confidence is LOW, meaning the AI is uncertain. ';
      explanation +=
          'Historically, signals with confidence below 35% have a win rate under 25%. ';
    } else if (conf < 50) {
      explanation +=
          '\n\nThe confidence is MODERATE. Signals at this level have about 30-40% win rate historically. ';
    } else {
      explanation +=
          '\n\nThe confidence is relatively HIGH for this model. Even so, historical win rate is around 40-50%. ';
    }

    if (vol > 8) {
      explanation +=
          '\n\nHigh volatility detected - price swings are larger, increasing both risk and potential reward.';
    } else if (vol < 3) {
      explanation +=
          '\n\nLow volatility detected - price is relatively stable, reducing both risk and potential reward.';
    }

    return explanation;
  }

  void _showManualTradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Trade Execution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Execute $action for $symbol?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Remember: This AI has a 30% win rate. Trade at your own risk.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Manual $action order placed for $symbol'),
                  backgroundColor: action == 'BUY' ? Colors.green : Colors.red,
                ),
              );
              // TODO: Integrate with actual trading execution
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'BUY' ? Colors.green : Colors.red,
            ),
            child: Text('Confirm $action'),
          ),
        ],
      ),
    );
  }
}
