import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'package:mytrademate/services/price_cache.dart';
import 'package:mytrademate/models/portfolio_models.dart';
import 'dart:convert';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  DioBinanceClient? _client;
  late PriceCache _cache;
  Future<PortfolioSnapshot>? _future;
  static const _kYesterdayKey = 'portfolio_yesterday_total_usdt';
  static const _kLastRefDate = 'portfolio_last_ref_yyyymmdd';
  bool _blocked = false;
  String? _blockMsg;

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
    try {
      // Check if paper trading is enabled
      final prefs = await TradingPrefs.load();
      final sp = await SharedPreferences.getInstance();
      
      // Check unified paper trading key (default to true for safety)
      final isPaper = sp.getBool('paper_trading_mode') ?? true;
      
      debugPrint('Portfolio: isPaper=$isPaper');
      
      // If paper trading is enabled, load paper portfolio
      if (isPaper) {
        setState(() {
          _blocked = false;
          _blockMsg = null;
        });
        return await _loadPaperPortfolio();
      }
      
      // Check for API keys
      final hasKeys = (prefs.apiKey?.isNotEmpty == true) && (prefs.apiSecret?.isNotEmpty == true);
      
      // Guard: do not call signed endpoints without keys
      if (!hasKeys) {
        setState(() {
          _blocked = true;
          _blockMsg = 'Connectează un exchange în Settings sau activează Paper Trading.';
        });
        return const PortfolioSnapshot([], 0.0, dailyPnl: 0.0);
      }
    } catch (e) {
      debugPrint('Portfolio load error: $e');
      setState(() {
        _blocked = true;
        _blockMsg = 'Error: ${e.toString()}';
      });
      return const PortfolioSnapshot([], 0.0, dailyPnl: 0.0);
    }
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
    final todayKey =
        DateTime.now().toUtc().toString().substring(0, 10); // YYYY-MM-DD
    final lastRef = sp.getString(_kLastRefDate);
    if (yesterday == null || lastRef != todayKey) {
      await sp.setDouble(_kYesterdayKey, snap0.totalUsdt);
      await sp.setString(_kLastRefDate, todayKey);
    }

    final daily = yesterday == null ? 0.0 : (snap0.totalUsdt - yesterday);
    return snap0.copyWith(dailyPnl: daily);
  }

  /// Load paper trading portfolio from SharedPreferences
  Future<PortfolioSnapshot> _loadPaperPortfolio() async {
    debugPrint('Loading paper portfolio...');
    final sp = await SharedPreferences.getInstance();
    final paperDataJson = sp.getString('paper_portfolio');
    
    // Initialize with default demo holdings if first time
    Map<String, double> holdings = {
      'USDT': 10000.0, // Start with $10,000 USDT
      'BTC': 0.1, // Some BTC
      'ETH': 1.0, // Some ETH
    };
    
    if (paperDataJson != null) {
      try {
        final data = json.decode(paperDataJson) as Map<String, dynamic>;
        holdings = Map<String, double>.from(data);
        debugPrint('Loaded paper holdings: $holdings');
      } catch (e) {
        debugPrint('Failed to load paper portfolio: $e');
      }
    } else {
      // Save initial holdings
      debugPrint('Creating initial paper portfolio');
      await _savePaperPortfolio(holdings);
    }
    
    // Convert holdings to portfolio snapshot
    final holdingsList = <Holding>[];
    double totalUsdt = 0.0;
    
    // Fetch prices for all non-USDT assets
    final prices = <String, double>{'USDT': 1.0};
    for (final asset in holdings.keys) {
      if (asset.toUpperCase() == 'USDT') continue;
      try {
        final price = await _client!.getPrice('${asset}USDT');
        prices[asset] = price;
      } catch (e) {
        debugPrint('Failed to get price for $asset: $e');
        prices[asset] = 0.0;
      }
    }
    
    // Build holdings list
    for (final entry in holdings.entries) {
      final asset = entry.key;
      final qty = entry.value;
      if (qty <= 0) continue;
      
      final priceUsdt = prices[asset] ?? 1.0;
      holdingsList.add(Holding(asset, qty, priceUsdt));
      totalUsdt += qty * priceUsdt;
    }
    
    // Calculate daily P&L
    final yesterday = sp.getDouble('${_kYesterdayKey}_paper');
    final todayKey = DateTime.now().toUtc().toString().substring(0, 10);
    final lastRef = sp.getString('${_kLastRefDate}_paper');
    
    if (yesterday == null || lastRef != todayKey) {
      await sp.setDouble('${_kYesterdayKey}_paper', totalUsdt);
      await sp.setString('${_kLastRefDate}_paper', todayKey);
    }
    
    final daily = yesterday == null ? 0.0 : (totalUsdt - yesterday);
    
    debugPrint('Paper portfolio loaded: $totalUsdt USDT');
    return PortfolioSnapshot(holdingsList, totalUsdt, dailyPnl: daily);
  }
  
  Future<void> _savePaperPortfolio(Map<String, double> holdings) async {
    final sp = await SharedPreferences.getInstance();
    final json_ = json.encode(holdings);
    await sp.setString('paper_portfolio', json_);
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
                if (_blocked) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _blockMsg ?? 'Connectează un exchange în Settings sau activează Paper Trading.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
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
                          const Text('Total (USDT)',
                              style: TextStyle(fontSize: 14)),
                          Text(
                            snap.totalUsdt.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (snap.dailyPnl >= 0 ? '+' : '') +
                                snap.dailyPnl.toStringAsFixed(2),
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
                            subtitle: Text(
                                '${h.qty} @ ${h.priceUsdt.toStringAsFixed(4)} USDT'),
                            trailing:
                                Text('$approx${value.toStringAsFixed(2)} USDT'),
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
