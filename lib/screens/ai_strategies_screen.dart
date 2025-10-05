import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'widgets/ai_status_card.dart';

class AIStrategiesScreen extends StatefulWidget {
  const AIStrategiesScreen({super.key});

  @override
  State<AIStrategiesScreen> createState() => _AIStrategiesScreenState();
}

class _AIStrategiesScreenState extends State<AIStrategiesScreen> {
  final AIService _ai = AIService();

  // Symbols we try to predict for. Unsupported pairs will be skipped gracefully.
  static const List<String> _symbols = [
    'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'TRUMPUSD', 'WIFUSD'
  ];

  final Map<String, AIPrediction?> _preds = {};
  bool _loading = false;
  String? _error;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    // light auto-refresh every 30s while on this screen
    _autoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchAll(silent: true));
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final Map<String, AIPrediction?> next = {};
    String? lastErr;
    for (final sym in _symbols) {
      try {
        final pred = await _ai.getPrediction(sym);
        next[sym] = pred;
      } catch (e) {
        // Keep going; remember only the last error so UI can show something helpful.
        lastErr = e.toString();
        next[sym] = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _preds
        ..clear()
        ..addAll(next);
      _error = lastErr;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Strategies', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _fetchAll(),
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your AI Module Status', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const AIStatusCard(),

              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildAIAlert(
                  context,
                  'ℹ️ AI indisponibil temporar',
                  _error!,
                  Colors.orange.shade700,
                  Icons.info_outline,
                ),
              ],

              const SizedBox(height: 24),
              Text('Predicții curente', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._symbols.map((s) => _buildPredictionTile(context, s, _preds[s])),

              const SizedBox(height: 24),
              Text('Insights & Alerts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._buildInsights(context),

              const SizedBox(height: 24),
              Text('Advanced Tools', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildBacktestingCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionTile(BuildContext context, String symbol, AIPrediction? p) {
    if (p == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.query_stats),
          title: Text(symbol),
          subtitle: const Text('Nicio predicție (AI indisponibil sau pair neacceptat).'),
        ),
      );
    }

    final actionColor = p.action.toLowerCase() == 'buy'
        ? Colors.greenAccent
        : (p.action.toLowerCase() == 'sell' ? Colors.redAccent : Colors.amberAccent);

    return Card(
      child: ListTile(
        leading: Icon(Icons.trending_up, color: actionColor),
        title: Text(symbol),
        subtitle: Text(
          'Acțiune: ${p.action.toUpperCase()}\n'
          'Încredere: ${p.confidence.toStringAsFixed(1)}%\n'
          'Ţintă: ${p.targetPrice.toStringAsFixed(2)}\n'
          'Volatilitate: ${p.volatility}',
        ),
        trailing: Text(
          p.action.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: actionColor),
        ),
      ),
    );
  }

  List<Widget> _buildInsights(BuildContext context) {
    final List<Widget> items = [];
    _preds.forEach((sym, p) {
      if (p == null) return;
      // Simple rules for demo alerts
      if (p.confidence >= 65 && p.action.toLowerCase() == 'buy') {
        items.add(_buildAIAlert(
          context,
          '💡 Oportunitate identificată',
          'Cumpără $sym. Încredere ${p.confidence.toStringAsFixed(0)}%. Țintă ${p.targetPrice.toStringAsFixed(2)}.',
          Colors.blue.shade700,
          Icons.lightbulb_outline,
        ));
      }
      if (p.confidence >= 65 && p.action.toLowerCase() == 'sell') {
        items.add(_buildAIAlert(
          context,
          '⚠️ Semnal de ieșire',
          'Vinde $sym. Încredere ${p.confidence.toStringAsFixed(0)}%.',
          Colors.red.shade700,
          Icons.warning_amber,
        ));
      }
    });

    if (items.isEmpty) {
      items.add(
        _buildAIAlert(
          context,
          'ℹ️ Nicio alertă puternică',
          'Momentan nu există semnale cu încredere > 65%.',
          Colors.grey.shade700,
          Icons.info_outline,
        ),
      );
    }

    return items;
  }

  Widget _buildAIAlert(BuildContext context, String title, String subtitle, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          if (title.contains('Oportunitate'))
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order ticket coming soon…')),
              ),
              child: const Text('ACT NOW', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildBacktestingCard(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Backtesting & Simulation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Testați performanța strategiilor pe date istorice pentru a estima profitabilitatea viitoare.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backtester UI coming soon.')),
              ),
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text('Run Backtest', style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
