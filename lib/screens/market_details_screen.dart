import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'trading_modal.dart';
import 'widgets/ai_prediction_card.dart';
import '../services/dio_binance_client.dart';
import '../services/market_data_service.dart';
import '../services/paper_broker.dart';
import '../l10n/strings.dart';
import '../ui/keys.dart';
import '../core/errors.dart';
import '../ui/error_ui.dart';
// removed unused alias import if not used directly as api

typedef LoadDataFn = Future<void> Function();

@visibleForTesting
const Key marketReloadBtnKey = Key('market.reload');

class MarketDetailsScreen extends StatefulWidget {
  final String symbol;
  final bool forTest;
  final LoadDataFn? loadDataFn; // for tests
  final LoadDataFn? reloadFn; // for tests
  /// For tests: hide AI card (which otherwise spins a FutureBuilder/network).
  final bool showAICard;
  /// Optional broker injection for tests; app falls back to DI/default.
  final PaperBroker? broker;
  const MarketDetailsScreen({
    super.key,
    required this.symbol,
    this.forTest = false,
    this.loadDataFn,
    this.reloadFn,
    this.showAICard = true,
    this.broker,
  });

  @override
  State<MarketDetailsScreen> createState() => _MarketDetailsScreenState();
}

class _MarketDetailsScreenState extends State<MarketDetailsScreen> {
  late Future<List<List<num>>> _klinesFuture;
  late Future<bool> _supportFuture;
  @visibleForTesting
  final chartLoadingKey = const Key('market.chart.loading');
  bool _reloading = false;
  StreamSubscription<double>? _priceSub;
  double? _lastPrice;
  late final PaperBroker _broker;
  UserError? _wsError;

  @override
  void initState() {
    super.initState();
    _broker = widget.broker ?? PaperBroker(null);
    _reload();
    // live price stream via MarketDataService (inherited)
    // Delay to have context available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final inh = InheritedMarketData.of(context);
      final svc = inh.service;
      final supported = await _isSymbolSupported(widget.symbol);
      if (!mounted) return;
      if (!supported) {
        // don't attach WS for unsupported symbols on testnet
        return;
      }
      await svc.start(widget.symbol);
      _priceSub = svc.prices(widget.symbol).listen((p) {
        if (!mounted) return;
        setState(() {
          _wsError = null;
          _lastPrice = p;
        });
      }, onError: (err) {
        if (!mounted) return;
        final u = err is UserError ? err : ErrorMapper.map(err);
        setState(() => _wsError = u);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(() {
      final hasProvider = InheritedMarketData.maybeOf(context) != null;
      if (!hasProvider) {
        throw FlutterError(
            'MarketData provider missing. Folosește wrapWithMarketData(...) în teste.');
      }
      return true;
    }());
  }

  Future<void> _loadData() async {
    if (widget.loadDataFn != null) {
      // Provide resolved futures for the UI when injected loader is used
      setState(() {
        _klinesFuture = Future<List<List<num>>>.value(<List<num>>[]);
        _supportFuture = Future<bool>.value(true);
      });
      return widget.loadDataFn!();
    } else {
      setState(() {
        if (widget.forTest) {
          _klinesFuture = Future.delayed(
              const Duration(milliseconds: 100),
              () =>
                  List.generate(10, (i) => [0, 0, 0, 0, 10000 + i.toDouble()]));
          _supportFuture = Future.value(true);
        } else {
          _klinesFuture = _fetchKlines(widget.symbol);
          _supportFuture = _isSymbolSupported(widget.symbol);
        }
      });
      await Future.wait([_klinesFuture, _supportFuture]);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _reloading = true;
    });
    try {
      if (widget.reloadFn != null) {
        // Ensure UI futures exist so widgets can build while reloadFn runs
        setState(() {
          _klinesFuture = Future<List<List<num>>>.value(<List<num>>[]);
          _supportFuture = Future<bool>.value(true);
        });
        await widget.reloadFn!();
      } else {
        await _loadData();
        // also force a REST refresh for the live price tile
        try {
          final svc = InheritedMarketData.of(context).service;
          await svc.refreshNow(widget.symbol);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  void dispose() {
    try {
      _priceSub?.cancel();
    } catch (_) {}
    // hint the service we no longer need this symbol if no other listeners
    try {
      final svc = InheritedMarketData.of(context).service;
      svc.stopIfOrphan(widget.symbol);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.symbol;
    // Format symbol consistently (e.g. "BTC/USDT" not "BTCUSDT")
    final displaySymbol = _formatSymbolForDisplay(symbol);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(displaySymbol, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            key: AppKeys.marketReload,
            onPressed: _reload,
            tooltip: S.marketRefresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_reloading) const LinearProgressIndicator(),
          // Support banner
          FutureBuilder<bool>(
            future: _supportFuture,
            builder: (context, suppSnap) {
              if (suppSnap.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final supported = suppSnap.data == true;
              if (supported) return const SizedBox.shrink();
              return Card(
                color: Colors.amber.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This symbol is not available on the current environment (e.g., Binance Testnet). Chart and orders may be disabled.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Spot price (live)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Semantics(
                liveRegion: true,
                container: true,
                excludeSemantics: true,
                label: S.lastPrice,
                value: _lastPrice != null
                    ? _lastPrice!.toStringAsFixed(2)
                    : '—',
                key: AppKeys.marketLiveRegion,
                child: _wsError != null
                    ? InlineErrorBox(
                        err: _wsError!,
                        onRetry: () {
                          setState(() => _wsError = null);
                          InheritedMarketData.of(context)
                              .service
                              .start(widget.symbol);
                        },
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(S.lastPrice, style: const TextStyle(fontSize: 14), key: AppKeys.marketPriceStreamStatus),
                          Text(
                            _lastPrice != null ? _lastPrice!.toStringAsFixed(2) : '—',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Chart card
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder<List<List<num>>>(
                  future: _klinesFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          key: ValueKey('market.chart.loading'),
                          child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          '${S.chartErrorPrefix}\n${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }
                    final data = snap.data;
                    if (data == null || data.isEmpty) {
                      return Center(child: Text(S.chartNoData));
                    }
                    final spots = <FlSpot>[];
                    for (var i = 0; i < data.length; i++) {
                      final v = data[i][4];
                      final close = v.toDouble();
                      spots.add(FlSpot(i.toDouble(), close));
                    }
                    double minY =
                        spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
                    double maxY =
                        spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
                    if (minY == maxY) {
                      // avoid zero range
                      final pad = minY.abs() * 0.01 + 1.0;
                      minY -= pad;
                      maxY += pad;
                    }
                    return LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            color: Colors.cyanAccent,
                            barWidth: 2,
                            spots: spots,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.cyanAccent, Colors.transparent],
                                stops: [0.0, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          if (widget.showAICard)
            AIPredictionCard(symbol: symbol)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 16),

          FutureBuilder<bool>(
            future: _supportFuture,
            builder: (context, suppSnap) {
              final supported = suppSnap.data == true;
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: supported
                          ? () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => TradingModal(
                                          assetSymbol: symbol, isBuying: true)));
                            }
                          : null,
                      icon: const Icon(Icons.shopping_cart, color: Colors.white),
                      label: const Text('Buy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      key: AppKeys.tradePlace,
                      onPressed: supported ? _onTapPlace : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Place', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: supported
                          ? () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => TradingModal(
                                          assetSymbol: symbol, isBuying: false)));
                            }
                          : null,
                      icon: const Icon(Icons.sell, color: Colors.white),
                      label: const Text('Sell', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _onTapPlace() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            key: AppKeys.confirmSheet,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Confirm ${widget.symbol} order'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: AppKeys.confirmPlace,
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _confirmAndMaybeUndo();
                  },
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndMaybeUndo() async {
    final req = PaperOrderReq.market(
      symbol: widget.symbol,
      side: OrderSide.buy,
      quantity: 0.01,
    );
    final orderId = await _broker.placeOrder(req);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final snack = SnackBar(
      duration: const Duration(seconds: 3),
      content: const Text('Order placed'),
      action: SnackBarAction(
        key: AppKeys.undoTrade,
        label: 'Undo',
        onPressed: () async {
          await _broker.cancelOrder(orderId);
        },
      ),
    );
    messenger.showSnackBar(snack);
  }
}

 

Future<List<List<num>>> _fetchKlines(String symbol) async {
  final client = await DioBinanceClient.createFromPrefs();
  final sym = _toBinanceSymbol(symbol);
  try {
    final data = await client.klines(sym, '1h', limit: 50);
    return data;
  } catch (e) {
    // Try a shorter interval as fallback
    try {
      return await client.klines(sym, '5m', limit: 120);
    } catch (e2) {
      throw Exception('Klines unavailable for $sym: $e2');
    }
  }
}

Future<bool> _isSymbolSupported(String symbol) async {
  try {
    final client = await DioBinanceClient.createFromPrefs();
    final sym = _toBinanceSymbol(symbol);
    // A lightweight way: if 24h ticker works, we consider it supported
    await client.ticker24h(sym);
    return true;
  } catch (_) {
    return false;
  }
}

String _toBinanceSymbol(String s) {
  final up = s.toUpperCase();
  if (up.contains('/')) {
    final parts = up.split('/');
    final base = parts[0];
    final quote = parts[1] == 'USD' ? 'USDT' : parts[1];
    return base + quote;
  }
  return up.replaceAll('USD', 'USDT');
}

String _formatSymbolForDisplay(String s) {
  // Convert internal format to display format: BTCUSDT -> BTC/USDT
  final binance = _toBinanceSymbol(s);
  if (binance.endsWith('USDT')) {
    final base = binance.substring(0, binance.length - 4);
    return '$base/USDT';
  }
  if (binance.endsWith('USDC')) {
    final base = binance.substring(0, binance.length - 4);
    return '$base/USDC';
  }
  if (binance.endsWith('BTC')) {
    final base = binance.substring(0, binance.length - 3);
    return '$base/BTC';
  }
  return binance;
}
