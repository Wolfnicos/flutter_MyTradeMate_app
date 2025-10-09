import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ohlcv_service.dart';
import '../ai/ai_locator.dart';
import '../ai/entities.dart' as ai;
import 'widgets/ai_status_card.dart';
import 'backtest_screen.dart';

class AIStrategiesScreen extends StatefulWidget {
  const AIStrategiesScreen({super.key});

  @override
  State<AIStrategiesScreen> createState() => _AIStrategiesScreenState();
}

class _AIStrategiesScreenState extends State<AIStrategiesScreen> {
  // 🤖 Use NEW AI Pipeline!
  OHLCVService? _ohlcvService;

  // Premium 5 crypto symbols - LIVE DATA ONLY
  // These are the only supported cryptocurrencies with real-time AI analysis
  static const List<String> _symbols = [
    'BTCUSDT',   // Bitcoin - Market leader, highest liquidity
    'ETHUSDT',   // Ethereum - Smart contracts, DeFi backbone
    'BNBUSDT',   // Binance Coin - Exchange utility token
    'WLFIUSDT',  // WLFI Token - DeFi governance token
    'TRUMPUSDT', // Trump token - Political meme coin (mainnet only)
  ];

  final Map<String, ai.Prediction?> _aiPreds = {};  // NEW AI predictions!
  bool _loading = false;
  String? _error;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _initServices();
    _fetchAll();
    // light auto-refresh every 30s while on this screen
    _autoTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchAll(silent: true));
  }
  
  Future<void> _initServices() async {
    try {
      _ohlcvService = await OHLCVService.createFromPrefs();
      debugPrint('✅ OHLCVService initialized in AI Strategies');
    } catch (e) {
      debugPrint('⚠️ OHLCVService init failed: $e');
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // Check AI initialized
    if (!AILocator.I.isInitialized) {
      debugPrint('⚠️ AILocator not initialized');
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _error = 'AI not initialized';
        });
      }
      return;
    }

    final Map<String, ai.Prediction?> next = {};
    String? lastErr;
    
    for (final sym in _symbols) {
      try {
        // 🤖 Use PredictionRepo pentru cache și consistency!
        final pred = await AILocator.I.repo.getFor(sym);
        
        next[sym] = pred;  // Store (poate fi null)
        
        // Logs sunt în PredictionRepo - nu mai duplicăm!
      } catch (e) {
        // Keep going; remember only the last error
        lastErr = e.toString();
        next[sym] = null;
        debugPrint('❌ Unexpected error for $sym: $e');
      }
    }
    
    if (!mounted) return;
    setState(() {
      _aiPreds
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
        title: const Text('AI Strategies',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _fetchAll(),
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
              Text('Your AI Module Status',
                  style: Theme.of(context).textTheme.titleLarge),
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
              Text('Predicții curente',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._symbols
                  .map((s) => _buildPredictionTile(context, s, _aiPreds[s])),
              const SizedBox(height: 8),
              Text('Insights & Alerts',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._buildInsights(context),
              const SizedBox(height: 24),
              Text('Advanced Tools',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildBacktestingCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionTile(
      BuildContext context, String symbol, ai.Prediction? p) {  // NEW AI Prediction!
    if (p == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.query_stats, color: Colors.grey),
          title: Text(symbol.replaceAll('USDT', '/USDT')),
          subtitle: const Text(
              'Nicio predicție (AI indisponibil sau pair neacceptat).'),
        ),
      );
    }

    // Get action from NEW AI prediction
    final action = AILocator.I.decide(p);
    final actionColor = action == 'BUY'
        ? Colors.greenAccent
        : (action == 'SELL'
            ? Colors.redAccent
            : Colors.amberAccent);

    final actionIcon = action == 'BUY'
        ? Icons.trending_up
        : (action == 'SELL'
            ? Icons.trending_down
            : Icons.pause_circle_outline);

    // Calculate prediction strength (NEW confidence!)
    final confPercent = p.confidencePercent;
    final strength = confPercent >= 75 
        ? 'Foarte puternică' 
        : (confPercent >= 60 ? 'Puternică' : 'Moderată');
    
    // Crypto-specific insights based on NEW volatility
    final volPercent = p.annVolPercent;
    final volInsight = volPercent >= 100
        ? '⚠️ Volatilitate ridicată - risc crescut'
        : (volPercent >= 50 
            ? '📊 Volatilitate moderată - risc echilibrat'
            : '✓ Volatilitate scăzută - stabil');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: actionColor.withValues(alpha: 102), width: 1.5),
      ),
      child: ExpansionTile(
        leading: Icon(actionIcon, color: actionColor, size: 28),
        title: Text(
          symbol.replaceAll('USDT', '/USDT'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '$action • $strength (${confPercent.toStringAsFixed(0)}%)',  // Use local vars!
          style: TextStyle(color: actionColor, fontWeight: FontWeight.w600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: actionColor.withValues(alpha: 51),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            p.action.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: actionColor,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('🎯 Return Estimat', '${p.expReturnPercent.toStringAsFixed(2)}%'),  // NEW!
                const SizedBox(height: 8),
                _buildDetailRow('📊 Probabilitate Creștere', '${(p.pBuy * 100).toStringAsFixed(1)}%'),  // NEW!
                const SizedBox(height: 8),
                _buildDetailRow('💰 Încredere', '${confPercent.toStringAsFixed(1)}%'),  // NEW!
                const SizedBox(height: 8),
                _buildDetailRow('⚡ Volatilitate Anualizată', '${volPercent.toStringAsFixed(1)}%'),  // NEW!
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(
                      volPercent >= 100 ? Icons.warning_amber : Icons.info_outline,  // NEW!
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        volInsight,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getCryptoStrategyTip(action, confPercent),  // NEW!
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _getCryptoStrategyTip(String action, double confidence) {  // NEW signature!
    if (action == 'BUY' && confidence >= 70) {
      return '💡 Strategie: Consider intrare treptată (DCA) pentru risc redus';
    } else if (action == 'SELL' && confidence >= 70) {
      return '💡 Strategie: Consider ieșire parțială pentru a bloca profit';
    } else if (action == 'HOLD') {
      return '💡 Strategie: Monitorizează piața, păstrează poziția curentă';
    } else {
      return '💡 Strategie: Încredere moderată - așteaptă confirmări suplimentare';
    }
  }

  List<Widget> _buildInsights(BuildContext context) {
    final List<Widget> items = [];
    _aiPreds.forEach((sym, p) {  // NEW: use _aiPreds!
      if (p == null) return;
      
      final action = AILocator.I.decide(p);
      final confPercent = p.confidencePercent;
      
      // Show only high-confidence signals (>= 65%)
      if (confPercent >= 65 && action == 'BUY') {
        items.add(_buildAIAlert(
          context,
          '💡 Oportunitate identificată',
          'Cumpără $sym. Încredere ${confPercent.toStringAsFixed(0)}%. Return ${p.expReturnPercent.toStringAsFixed(1)}%.',  // NEW!
          Colors.blue.shade700,
          Icons.lightbulb_outline,
        ));
      }
      if (confPercent >= 65 && action == 'SELL') {  // NEW!
        items.add(_buildAIAlert(
          context,
          '⚠️ Semnal de ieșire',
          'Vinde $sym. Încredere ${confPercent.toStringAsFixed(0)}%.',  // NEW!
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

  Widget _buildAIAlert(BuildContext context, String title, String subtitle,
      Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 128)),
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
                Text(title,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
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
              child: const Text('ACT NOW',
                  style: TextStyle(
                      color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
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
            const Text('Backtesting & Simulation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Testați performanța strategiilor pe date istorice pentru a estima profitabilitatea viitoare.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BacktestScreen()),
                );
              },
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text('Run Backtest',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
