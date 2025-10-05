import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/services/price_cache.dart';
import 'package:mytrademate/models/portfolio_models.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  DioBinanceClient? _client;
  late PriceCache _cache;
  Future<PortfolioSnapshot>? _future;
  static const _kYesterdayKey = 'portfolio_yesterday_total_usdt';
  static const _kLastRefDate = 'portfolio_last_ref_yyyymmdd';

  @override
  void initState() {
    super.initState();
    _cache = PriceCache();
    _init();
  }

  Future<void> _init() async {
    final c = await DioBinanceClient.createFromPrefs(priceCache: _cache);
    setState(() {
      _client = c;
      _future = _load();
    });
  }

  Future<PortfolioSnapshot> _load() async {
    final acc = await _client!.account();
    final balances = (acc['balances'] as List).cast<Map>();

    // Gather prices: USDT=1.0 and per-asset for non-USDT
    final symbols = <String>{};
    for (final b in balances) {
      final asset = b['asset']?.toString() ?? '';
      if (asset.isEmpty || asset.toUpperCase() == 'USDT') continue;
      symbols.add('${asset}USDT');
    }
    final prices = <String, double>{'USDT': 1.0};
    for (final sym in symbols) {
      final asset = sym.replaceAll('USDT', '');
      prices[asset] = await _client!.getPrice(sym);
    }

    final holdings = PortfolioAggregator.toHoldingsFromBalances(balances);
    final sp = await SharedPreferences.getInstance();
    final yesterday = sp.getDouble(_kYesterdayKey);
    final snap0 = PortfolioAggregator.compute(holdings, prices);

    // Baseline rollover: set reference once per UTC day
    final todayKey = DateTime.now().toUtc().toString().substring(0, 10); // YYYY-MM-DD
    final lastRef = sp.getString(_kLastRefDate);
    if (yesterday == null || lastRef != todayKey) {
      await sp.setDouble(_kYesterdayKey, snap0.totalUsdt);
      await sp.setString(_kLastRefDate, todayKey);
    }

    final daily = yesterday == null ? 0.0 : (snap0.totalUsdt - yesterday);
    return snap0.copyWith(dailyPnl: daily);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<PortfolioSnapshot>(
              future: _future,
              builder: (ctx, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  return Center(child: Text('Error: ${s.error}'));
                }
                final snap = s.data!;
                final pnlColor = snap.dailyPnl >= 0 ? Colors.green : Colors.red;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total (USDT)', style: TextStyle(fontSize: 14)),
                          Text(
                            snap.totalUsdt.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (snap.dailyPnl >= 0 ? '+' : '') + snap.dailyPnl.toStringAsFixed(2),
                            style: TextStyle(fontSize: 16, color: pnlColor),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: snap.holdings.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final h = snap.holdings[i];
                          final value = h.qty * h.priceUsdt;
                          final approx = h.priceUsdt == 0.0 ? '~ ' : '';
                          return ListTile(
                            title: Text(h.asset),
                            subtitle: Text('${h.qty} @ ${h.priceUsdt.toStringAsFixed(4)} USDT'),
                            trailing: Text('${approx}${value.toStringAsFixed(2)} USDT'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
