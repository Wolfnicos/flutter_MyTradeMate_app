import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final color = widget.isUp ? Colors.green : Colors.red;
    final priceStr =
        _livePrice != null ? _livePrice!.toStringAsFixed(2) : widget.price;

    final leadingSymbol =
        widget.symbol.contains('/') ? widget.symbol.split('/').first : widget.symbol;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Text(
          leadingSymbol,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          maxLines: 1,
        ),
      ),
      title: Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(widget.name, style: const TextStyle(color: Colors.white70)),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('\$$priceStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(widget.change, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
      onTap: widget.onTap,
    );
  }
}
