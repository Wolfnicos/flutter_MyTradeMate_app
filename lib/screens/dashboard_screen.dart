import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'portfolio_screen.dart';
import 'order_history_screen.dart';
import 'settings_screen.dart';
import 'market_details_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mytrademate/services/dio_binance_client.dart' as api;
import 'widgets/ai_alert_card.dart';
import 'widgets/asset_tile.dart';
// removed unused: price_stream import
import '../services/price_stream_manager.dart';
import '../services/mtm_models.dart';

class DashboardScreen extends StatefulWidget {
  final bool forTest;
  const DashboardScreen({super.key, this.forTest = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

@visibleForTesting
const Key dashboardPortfolioKey = Key('dash.portfolio');
@visibleForTesting
const Key dashboardOrdersKey = Key('dash.orders');
@visibleForTesting
const Key dashboardExplainKey = Key('dash.explain');
@visibleForTesting
const Key dashboardSettingsKey = Key('dash.settings');

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<double>? _sub;
  late final PriceStreamManager _pm;
  final Map<String, double> _lastPrices = {};
  double? _lastPrice; // BTCUSDT display


  @override
  void initState() {
    super.initState();
    _pm = PriceStreamManager();
    if (!widget.forTest) {
      _pm.attach('BTCUSDT').then((s) {
        _sub = s.listen((price) {
          if (!mounted) return;
          setState(() {
            _lastPrices['BTCUSDT'] = price;
            _lastPrice = price;
          });
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final m = await MtmModels.instance();
          await m.selfTest();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI models loaded ✅')),
          );
        } catch (e) {
          debugPrint('AI selfTest failed: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pm.detach('BTCUSDT');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.forTest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MyTradeMate', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Assets', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              AssetTile(
                key: dashboardOrdersKey,
                symbol: 'ETH/USD',
                name: 'Ethereum',
                price: '100.00',
                change: '+0.0%',
                isUp: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              AssetTile(
                key: dashboardSettingsKey,
                symbol: 'WIF/USD',
                name: 'WIF',
                price: '1.00',
                change: '+0.0%',
                isUp: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyTradeMate', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.red),
            onPressed: () {
              // Navigare către notificări
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Header Portofoliu ---
            const Text('Portfolio Total', style: TextStyle(color: Colors.white70, fontSize: 16)),
            Row(
              crossAxisAlignment: TextBaseline.alphabetic == null ? CrossAxisAlignment.start : CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    _lastPrice == null ? '—' : '\$${_lastPrice!.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: _ticker('BTCUSDT'),
                  builder: (context, s) {
                    if (!s.hasData) return const SizedBox();
                    final ch = (s.data!['priceChangePercent'] ?? '0').toString();
                    final isUp = !ch.startsWith('-');
                    final color = isUp ? Colors.green : Colors.red;
                    return Text('${ch}%', style: TextStyle(color: color));
                  },
                ),
              ],
            ),

            const SizedBox(height: 25),

            // --- 2. Alertă AI Proeminentă ---
            const AIAlertCard(),

            const SizedBox(height: 30),

            // --- 3. Portfolio Performance (BTCUSDT klines) ---
            Text('Portfolio Performance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FutureBuilder<List<List<num>>>(
                    future: _klines('BTCUSDT'),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final data = snap.data!;
                      final spots = <FlSpot>[];
                      for (var i = 0; i < data.length; i++) {
                        final v = data[i][4];
                        final close = v is num ? v.toDouble() : double.parse(v.toString());
                        spots.add(FlSpot(i.toDouble(), close));
                      }
                      final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
                      final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
                      return LineChart(LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(spots: spots, isCurved: true, color: Colors.cyanAccent, barWidth: 2, dotData: const FlDotData(show: false)),
                        ],
                      ));
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- 4. Your Assets (live BTC & ETH) ---
            Text('Your Assets', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 15),
            FutureBuilder<Map<String, dynamic>>(
              future: _ticker('BTCUSDT'),
              builder: (context, s) {
                final price = s.hasData ? (double.tryParse((s.data!['lastPrice'] ?? s.data!['price']).toString()) ?? 0).toStringAsFixed(2) : '—';
                final ch = s.hasData ? ((s.data!['priceChangePercent'] ?? '0').toString()) : '—';
                final isUp = ch != '—' ? (!ch.startsWith('-') && (double.tryParse(ch) ?? 0) >= 0) : true;
                return AssetTile(
                  key: dashboardPortfolioKey,
                  symbol: 'BTC/USD',
                  name: 'Bitcoin',
                  price: price,
                  change: ch == '—' ? ch : '$ch%',
                  isUp: isUp,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PortfolioScreen()),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _ticker('ETHUSDT'),
              builder: (context, s) {
                final price = s.hasData ? (double.tryParse((s.data!['lastPrice'] ?? s.data!['price']).toString()) ?? 0).toStringAsFixed(2) : '—';
                final ch = s.hasData ? ((s.data!['priceChangePercent'] ?? '0').toString()) : '—';
                final isUp = ch != '—' ? (!ch.startsWith('-') && (double.tryParse(ch) ?? 0) >= 0) : true;
                return AssetTile(
                  key: dashboardOrdersKey,
                  symbol: 'ETH/USD',
                  name: 'Ethereum',
                  price: price,
                  change: ch == '—' ? ch : '$ch%',
                  isUp: isUp,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _ticker('BNBUSDT'),
              builder: (context, s) {
                final price = s.hasData ? (double.tryParse((s.data!['lastPrice'] ?? s.data!['price']).toString()) ?? 0).toStringAsFixed(2) : '—';
                final ch = s.hasData ? ((s.data!['priceChangePercent'] ?? '0').toString()) : '—';
                final isUp = ch != '—' ? (!ch.startsWith('-') && (double.tryParse(ch) ?? 0) >= 0) : true;
                return AssetTile(
                  key: dashboardExplainKey,
                  symbol: 'BNB/USD',
                  name: 'BNB',
                  price: price,
                  change: ch == '—' ? ch : '$ch%',
                  isUp: isUp,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Explain is available from AI cards')),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<bool>(
  future: _supports('TRUMPUSDT'),
  builder: (context, s) {
    if (s.data != true) return const SizedBox();
    return FutureBuilder<Map<String, dynamic>>(
      future: _ticker('TRUMPUSDT'),
      builder: (context, t) {
        final price = t.hasData ? (double.tryParse((t.data!['lastPrice'] ?? t.data!['price']).toString()) ?? 0).toStringAsFixed(2) : '—';
        final ch = t.hasData ? ((t.data!['priceChangePercent'] ?? '0').toString()) : '—';
        final isUp = ch != '—' ? (!ch.startsWith('-') && (double.tryParse(ch) ?? 0) >= 0) : true;
        return AssetTile(
          symbol: 'TRUMP/USD',
          name: 'TRUMP',
          price: price,
          change: ch == '—' ? ch : '$ch%',
          isUp: isUp,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MarketDetailsScreen(symbol: 'TRUMP/USDT')),
            );
          },
        );
      },
    );
  },
),
            const SizedBox(height: 10),
            FutureBuilder<bool>(
  future: _supports('WIFUSDT'),
  builder: (context, s) {
    if (s.data != true) return const SizedBox();
    return FutureBuilder<Map<String, dynamic>>(
      future: _ticker('WIFUSDT'),
      builder: (context, t) {
        final price = t.hasData ? (double.tryParse((t.data!['lastPrice'] ?? t.data!['price']).toString()) ?? 0).toStringAsFixed(2) : '—';
        final ch = t.hasData ? ((t.data!['priceChangePercent'] ?? '0').toString()) : '—';
        final isUp = ch != '—' ? (!ch.startsWith('-') && (double.tryParse(ch) ?? 0) >= 0) : true;
        return AssetTile(
          symbol: 'WIF/USD',
          name: 'WIF',
          price: price,
          change: ch == '—' ? ch : '$ch%',
          isUp: isUp,
          key: dashboardSettingsKey,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        );
      },
    );
  },
),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon: full asset list')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('View All Assets', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

Future<bool> _supports(String symbol) async {
  try {
    final c = await api.DioBinanceClient.createFromPrefs();
    return c.supportsSymbol(symbol);
  } catch (_) {
    return false;
  }
}

Future<List<List<num>>> _klines(String symbol) async {
  final c = await api.DioBinanceClient.createFromPrefs();
  return c.klines(symbol, '1h', limit: 50);
}

Future<Map<String, dynamic>> _ticker(String symbol) async {
  final c = await api.DioBinanceClient.createFromPrefs();
  try { return await c.ticker24h(symbol); } catch (_) { final p = await c.tickerPrice(symbol); return {'price': p}; }
}

  

  Widget _buildAssetTile(BuildContext context, String symbol, String name, String price, String change, Color iconColor) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Text(symbol[0], style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
      ),
      title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(name, style: const TextStyle(color: Colors.white70)),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\$$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(
            change,
            style: TextStyle(color: change.contains('+') ? Colors.green : Colors.red, fontSize: 14),
          ),
        ],
      ),
      onTap: () {
        // Navigare către Detalii Active
      },
    );
  }
}
