import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mytrademate/services/price_stream_manager.dart';

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
  // Show a few majors + the two meme tickers. TRUMP/WIF are not on Binance testnet.
  final List<_CoinDef> _coins = const [
    _CoinDef(symbol: 'BTCUSDT', label: 'BTC', supportedOnTestnet: true),
    _CoinDef(symbol: 'ETHUSDT', label: 'ETH', supportedOnTestnet: true),
    _CoinDef(symbol: 'BNBUSDT', label: 'BNB', supportedOnTestnet: true),
    _CoinDef(symbol: 'TRUMPUSDT', label: 'TRUMP', supportedOnTestnet: false),
    _CoinDef(symbol: 'WIFUSDT', label: 'WIF', supportedOnTestnet: false),
  ];

  final Map<String, StreamSubscription<double>> _subs = {};
  final Map<String, double> _lastPrice = {};
  late final PriceStreamManager _pm;

  @override
  void initState() {
    super.initState();
    _pm = PriceStreamManager();
    for (final c in _coins) {
      if (!c.supportedOnTestnet)
        continue; // don't try to connect if not supported
      _pm.attach(c.symbol).then((stream) {
        if (!mounted) return;
        _subs[c.symbol] = stream.listen((p) {
          if (!mounted) return;
          setState(() => _lastPrice[c.symbol] = p);
        });
      });
    }
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
        title: const Text('Market'),
      ),
      body: ListView.separated(
        itemCount: _coins.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = _coins[index];
          final price = _lastPrice[c.symbol];
          final notOnTestnet = !c.supportedOnTestnet;
          return ListTile(
            leading: CircleAvatar(child: Text(c.label.substring(0, 1))),
            title: Row(
              children: [
                Text(c.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (notOnTestnet)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: const Text(
                      'Not on testnet',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            subtitle: Text(notOnTestnet
                ? 'Live stream disabled'
                : (price == null
                    ? 'Loading…'
                    : 'Last: ${price.toStringAsFixed(2)}')),
            trailing: const Icon(Icons.chevron_right),
            onTap: notOnTestnet
                ? null
                : () {
                    // If you have a details page route, push it here. Safe no-op otherwise.
                    // Navigator.of(context).pushNamed('/market/details', arguments: c.symbol);
                  },
          );
        },
      ),
    );
  }
}
