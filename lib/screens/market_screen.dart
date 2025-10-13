import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mytrademate/services/price_stream_manager.dart';
import 'market_details_screen.dart';
import '../services/dio_binance_client.dart' as api;
import '../widgets/premium_widgets.dart';
import 'widgets/asset_tile.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _CoinDef {
  const _CoinDef({
    required this.symbol,
    required this.label,
    this.supportedOnTestnet = true,
  });

  final String symbol; // e.g., BTCUSDT
  final String label; // e.g., BTC
  final bool supportedOnTestnet;
}

class _MarketScreenState extends State<MarketScreen> {
  // Premium 5 cryptocurrencies - LIVE DATA ONLY
  final List<_CoinDef> _coins = const [
    _CoinDef(symbol: 'BTCUSDT', label: 'BTC', supportedOnTestnet: true),
    _CoinDef(symbol: 'ETHUSDT', label: 'ETH', supportedOnTestnet: true),
    _CoinDef(symbol: 'BNBUSDT', label: 'BNB', supportedOnTestnet: true),
    _CoinDef(symbol: 'WLFIUSDT', label: 'WLFI', supportedOnTestnet: false),
    _CoinDef(symbol: 'TRUMPUSDT', label: 'TRUMP', supportedOnTestnet: false),
  ];

  final Map<String, StreamSubscription<double>> _subs = {};
  final Map<String, double> _lastPrice = {};
  final Map<String, String> _errors = {};
  final Map<String, double> _chg = {};
  late final PriceStreamManager _pm;

  @override
  void initState() {
    super.initState();
    _pm = PriceStreamManager();
    _prefetchTickers();
    for (final c in _coins) {
      if (!c.supportedOnTestnet) {
        continue; // don't try to connect if not supported
      }
      _pm.attach(c.symbol).then((stream) {
        if (!mounted) return;
        _subs[c.symbol] = stream.listen(
          (p) {
            if (!mounted) return;
            setState(() {
              _errors.remove(c.symbol);
              _lastPrice[c.symbol] = p;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _errors[c.symbol] = 'Live stream disabled');
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _errors[c.symbol] = 'Live stream disabled');
          },
          cancelOnError: true,
        );
      });
    }
  }

  Future<void> _prefetchTickers() async {
    try {
      final client = await api.DioBinanceClient.createFromPrefs();
      for (final c in _coins) {
        try {
          final t = await client.ticker24h(c.symbol);
          final raw = t['priceChangePercent'];
          final v =
              raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;
          if (!mounted) continue;
          setState(() => _chg[c.symbol] = v);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    for (final c in _coins) {
      if (c.supportedOnTestnet) {
        _pm.detach(c.symbol);
      }
    }
    _subs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Markets'), backgroundColor: Colors.transparent),
      body: ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: _coins.length,
          itemBuilder: (context, index) {
            final c = _coins[index];
            final price = _lastPrice[c.symbol] ?? 0.0;
            final ch = _chg[c.symbol] ?? 0.0;
            final changeStr =
                '${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(3)}%';
            return AssetTile(
              symbol: c.symbol,
              name: c.label,
              price: price == 0.0 ? '0.00' : price.toStringAsFixed(2),
              change: changeStr,
              isUp: ch >= 0,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => MarketDetailsScreen(symbol: c.symbol)),
                );
              },
            );
          }),
    );
  }
}
