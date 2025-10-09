import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:mytrademate/services/dio_binance_client.dart' as api;

/// Lightweight asset list tile that shows live price via periodic REST polling.
/// WebSocket streaming was removed here to avoid platform/DNS issues on simulator
/// and to simplify dependencies.
class AssetTile extends StatefulWidget {
  final String symbol; // e.g. BTCUSDT or BTC/USD (handled in display only)
  final String name;
  final String price; // fallback/initial price string
  final String change;
  final bool isUp;
  final VoidCallback? onTap;

  const AssetTile({
    super.key,
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.isUp,
    this.onTap,
  });

  @override
  State<AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends State<AssetTile> {
  Timer? _poll;
  double? _livePrice;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _startPoll();
  }

  void _startPoll() async {
    _poll?.cancel();
    final client = await api.DioBinanceClient.createFromPrefs();
    // Try immediately once
    () async {
      try {
        final t = await client.ticker24h(widget.symbol);
        final p = double.tryParse((t['lastPrice'] ?? t['price']).toString());
        if (p != null && mounted) setState(() => _livePrice = p);
      } catch (_) {
        try {
          final p = await client.tickerPrice(widget.symbol);
          if (mounted) setState(() => _livePrice = p);
        } catch (_) {}
      }
    }();

    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final t = await client.ticker24h(widget.symbol);
        final p = double.tryParse((t['lastPrice'] ?? t['price']).toString());
        if (p != null && mounted) {
          setState(() => _livePrice = p);
        }
      } catch (_) {
        try {
          final p = await client.tickerPrice(widget.symbol);
          if (mounted) setState(() => _livePrice = p);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }

  /// Returns icon, color and label for each crypto
  Map<String, dynamic> _getCryptoInfo(String sym) {
    final s = sym.toUpperCase();
    if (s.contains('BTC')) {
      return {'icon': Icons.currency_bitcoin, 'color': const Color(0xFFF7931A), 'label': 'BTC', 'name': 'Bitcoin'};
    } else if (s.contains('ETH')) {
      return {'icon': Icons.diamond, 'color': const Color(0xFF627EEA), 'label': 'ETH', 'name': 'Ethereum'};
    } else if (s.contains('BNB')) {
      return {'icon': Icons.toll, 'color': const Color(0xFFF3BA2F), 'label': 'BNB', 'name': 'BNB'};
    } else if (s.contains('TRUMP')) {
      return {'icon': Icons.flag, 'color': const Color(0xFFDC143C), 'label': 'TRUMP', 'name': 'TRUMP'};
    } else if (s.contains('WLFI')) {
      return {'icon': Icons.token, 'color': const Color(0xFF1E88E5), 'label': 'WLFI', 'name': 'WLFI'};
    } else {
      return {'icon': Icons.currency_exchange, 'color': Colors.grey, 'label': 'CRYPTO', 'name': 'Crypto'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isUp ? Colors.green : Colors.red;
    final priceStr =
        _livePrice != null ? _livePrice!.toStringAsFixed(2) : widget.price;

    final cryptoInfo = _getCryptoInfo(widget.symbol);
    final IconData cryptoIcon = cryptoInfo['icon'] as IconData;
    final Color cryptoColor = cryptoInfo['color'] as Color;
    final String cryptoLabel = cryptoInfo['label'] as String;
    final String cryptoName = cryptoInfo['name'] as String;

    return Semantics(
      label:
          'Asset ${widget.symbol}, price $priceStr, change ${widget.change}',
      child: ListTile(
      leading: CircleAvatar(
        backgroundColor: cryptoColor.withOpacity(0.2),
        child: Icon(
          cryptoIcon,
          color: cryptoColor,
          size: 28,
        ),
      ),
      title: Text(
        '$cryptoName ($cryptoLabel)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        widget.symbol,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\$$priceStr',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(widget.change, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
      ),
    );
  }
}
