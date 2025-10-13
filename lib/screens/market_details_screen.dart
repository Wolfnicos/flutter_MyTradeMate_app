import 'package:flutter/material.dart';
import 'dart:async';
import 'trading_modal.dart';
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
    this.showAICard = false,
    this.broker,
  });

  @override
  State<MarketDetailsScreen> createState() => _MarketDetailsScreenState();
}

class _MarketDetailsScreenState extends State<MarketDetailsScreen> {
  late Future<List<List<num>>> _klinesFuture;
  late Future<bool> _supportFuture;
  Future<Map<String, dynamic>>? _tickerFuture;
  @visibleForTesting
  final chartLoadingKey = const Key('market.chart.loading');
  bool _reloading = false;
  StreamSubscription<double>? _priceSub;
  double? _lastPrice;
  late final PaperBroker _broker;
  UserError? _wsError;
  String _interval = '1h'; // default timeframe
  double? _crossX; // crosshair x position
  List<List<num>>? _cachedKlines; // keep last chart during reloads
  bool _showVol = true;
  bool _showEma = false;

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
          _tickerFuture = Future.value(<String, dynamic>{});
        } else {
          _klinesFuture =
              _fetchKlinesInterval(widget.symbol, _interval).then((d) {
            _cachedKlines = d;
            return d;
          });
          _supportFuture = _isSymbolSupported(widget.symbol);
          _tickerFuture = _fetchTicker24h(widget.symbol);
        }
      });
      await Future.wait([
        _klinesFuture,
        _supportFuture,
        if (_tickerFuture != null) _tickerFuture!,
      ]);
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          displaySymbol,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.onSurface),
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
          // no explicit loading indicators to keep UI clean
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

          // Spot price (live) + 24h stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Semantics(
                liveRegion: true,
                container: true,
                excludeSemantics: true,
                label: S.lastPrice,
                value:
                    _lastPrice != null ? _lastPrice!.toStringAsFixed(2) : '—',
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
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(S.lastPrice,
                                  style: const TextStyle(fontSize: 14),
                                  key: AppKeys.marketPriceStreamStatus),
                              Text(
                                _lastPrice != null
                                    ? _lastPrice!.toStringAsFixed(2)
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _tickerFuture,
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final t = snap.data!;
                              double parseD(v) => (v is num)
                                  ? v.toDouble()
                                  : double.tryParse('$v') ?? 0;
                              final ch = parseD(t['priceChangePercent']);
                              final high = parseD(t['highPrice']);
                              final low = parseD(t['lowPrice']);
                              final vol = parseD(t['volume']);
                              final chColor = ch >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent;
                              TextStyle small([Color? c]) => TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c);
                              return Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  Row(children: [
                                    const Text('24h',
                                        style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${ch.toStringAsFixed(2)}%',
                                      style: small(chColor),
                                    ),
                                  ]),
                                  Text('High: ${high.toStringAsFixed(2)}',
                                      style: small()),
                                  Text('Low: ${low.toStringAsFixed(2)}',
                                      style: small()),
                                  Text('Vol: ${vol.toStringAsFixed(0)}',
                                      style: small()),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          // Timeframe switcher
          _TimeframeChips(
            value: _interval,
            onChanged: (v) {
              if (v == _interval) return;
              setState(() => _interval = v);
              _loadData();
            },
          ),
          const SizedBox(height: 8),

          // Overlays toggles
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Volume'),
                selected: _showVol,
                onSelected: (s) => setState(() => _showVol = s),
              ),
              FilterChip(
                label: const Text('EMA20/50'),
                selected: _showEma,
                onSelected: (s) => setState(() => _showEma = s),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chart card (TradingView-like)
          SizedBox(
            height: 260,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FutureBuilder<List<List<num>>>(
                  future: _klinesFuture,
                  builder: (context, snap) {
                    // Keep last good chart; hide spinners completely
                    List<List<num>>? data;
                    if (snap.connectionState == ConnectionState.done &&
                        !snap.hasError) {
                      data = snap.data;
                    } else {
                      data = _cachedKlines;
                    }
                    if (data == null || data.isEmpty) {
                      return const SizedBox();
                    }
                    final cs = Theme.of(context).colorScheme;
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 10,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: CustomPaint(
                        painter: CandlesPainter(
                          data,
                          up: const Color(0xFF10B981), // green
                          down: const Color(0xFFEF4444), // red
                          crossX: null, // crosshair disabled while zoom enabled
                          theme: cs,
                          showVolume: _showVol,
                          showEma: _showEma,
                        ),
                        size: const Size(double.infinity, double.infinity),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          // AI card removed here per performance request
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
                                          assetSymbol: symbol,
                                          isBuying: true)));
                            }
                          : null,
                      icon:
                          const Icon(Icons.shopping_cart, color: Colors.white),
                      label: const Text('Buy',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
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
                                          assetSymbol: symbol,
                                          isBuying: false)));
                            }
                          : null,
                      icon: const Icon(Icons.sell, color: Colors.white),
                      label: const Text('Sell',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
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

class _TimeframeChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TimeframeChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = ['5m', '15m', '1h', '4h', '1d'];
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it),
            selected: value == it,
            onSelected: (s) => onChanged(it),
            selectedColor: cs.primary.withOpacity(0.2),
            labelStyle: TextStyle(
              color: value == it ? cs.primary : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: cs.surfaceContainerHighest.withOpacity(0.2),
          ),
      ],
    );
  }
}

class CandlesPainter extends CustomPainter {
  final List<List<num>>
      klines; // [openTime, open, high, low, close, volume,...]
  final Color up;
  final Color down;
  final double? crossX;
  final ColorScheme theme;
  final bool showVolume;
  final bool showEma;
  CandlesPainter(this.klines,
      {required this.up,
      required this.down,
      required this.crossX,
      required this.theme,
      this.showVolume = false,
      this.showEma = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (klines.isEmpty) return;
    final n = klines.length;
    final doubles =
        klines.map((e) => e.map((v) => v.toDouble()).toList()).toList();
    final highs = doubles.map((e) => e[2]).toList();
    final lows = doubles.map((e) => e[3]).toList();
    final closes = doubles.map((e) => e[4]).toList();
    final volumes =
        doubles.map((e) => (e.length > 5 ? e[5] : 0).toDouble()).toList();
    double minY = lows.reduce((a, b) => a < b ? a : b);
    double maxY = highs.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      final pad = minY.abs() * 0.01 + 1.0;
      minY -= pad;
      maxY += pad;
    }
    final range = maxY - minY;
    double y(double v) => size.height - ((v - minY) / range) * size.height;

    final candleW = size.width / n;
    final wickPaint = Paint()
      ..strokeWidth = candleW < 3 ? 0.8 : 1.1
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;
    // subtle grid like TradingView
    final grid = Paint()
      ..color = theme.surfaceContainerHighest.withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (int i = 1; i < 4; i++) {
      final yy = size.height * i / 4;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), grid);
    }
    for (int i = 0; i < n; i++) {
      final o = doubles[i][1];
      final h = doubles[i][2];
      final l = doubles[i][3];
      final c = doubles[i][4];
      final bullish = c >= o;
      final color = bullish ? up : down;
      wickPaint.color = color.withOpacity(0.95);
      final cx = (i + 0.5) * candleW;
      // wicks
      canvas.drawLine(Offset(cx, y(l)), Offset(cx, y(h)), wickPaint);
      // body
      final half = (candleW * 0.45).clamp(0.9, 3.2);
      final center = i * candleW + candleW * 0.5;
      final bodyLeft = center - half;
      final bodyRight = center + half;
      double top = y(bullish ? c : o);
      double bottom = y(bullish ? o : c);
      // min body height for visibility on tiny TFs
      if ((bottom - top).abs() < 1.2) {
        final mid = (top + bottom) / 2;
        top = mid - 0.6;
        bottom = mid + 0.6;
      }
      final r = RRect.fromLTRBR(
          bodyLeft, top, bodyRight, bottom, const Radius.circular(2));
      // TradingView-like: filled for bullish, hollow for bearish
      final bodyPaint = Paint()
        ..color = bullish ? color.withOpacity(0.9) : Colors.transparent
        ..style = bullish ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true;
      canvas.drawRRect(r, bodyPaint);
      if (!bullish) {
        final stroke = Paint()
          ..color = color.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRRect(r, stroke);
      }
    }

    // crosshair (vertical)
    if (crossX != null) {
      final p = Paint()
        ..color = theme.primary.withOpacity(0.45)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      final x = crossX!.clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }

    // Volume bars at bottom (20% height)
    if (showVolume) {
      final volMax =
          volumes.isEmpty ? 0.0 : volumes.reduce((a, b) => a > b ? a : b);
      final volH = size.height * 0.2;
      final top = size.height - volH;
      final p = Paint()..strokeWidth = (candleW * 0.5).clamp(1.0, 4.0);
      for (int i = 0; i < n; i++) {
        final bullish = doubles[i][4] >= doubles[i][1];
        p.color = (bullish ? up : down).withOpacity(0.6);
        final ratio = volMax == 0 ? 0 : volumes[i] / volMax;
        final h = volH * ratio;
        final x = (i + 0.5) * candleW;
        canvas.drawLine(Offset(x, top + volH), Offset(x, top + volH - h), p);
      }
    }

    // EMA overlays
    if (showEma) {
      List<double> ema(List<double> src, int period) {
        final alpha = 2.0 / (period + 1);
        double prev = src.first;
        final out = <double>[];
        for (final v in src) {
          prev = alpha * v + (1 - alpha) * prev;
          out.add(prev);
        }
        return out;
      }

      final ema20 = ema(closes, 20);
      final ema50 = ema(closes, 50);
      final p20 = Paint()
        ..color = theme.tertiary.withOpacity(0.9)
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      final p50 = Paint()
        ..color = theme.secondary.withOpacity(0.9)
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      double lx = 0, ly = 0;
      for (int i = 0; i < n; i++) {
        final x = (i + 0.5) * candleW;
        final y20 = y(ema20[i]);
        final y50 = y(ema50[i]);
        if (i > 0) {
          canvas.drawLine(Offset(lx, ly), Offset(x, y20), p20);
        }
        lx = x;
        ly = y20;
      }
      lx = 0;
      ly = 0;
      for (int i = 0; i < n; i++) {
        final x = (i + 0.5) * candleW;
        final v = y(ema50[i]);
        if (i > 0) {
          canvas.drawLine(Offset(lx, ly), Offset(x, v), p50);
        }
        lx = x;
        ly = v;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CandlesPainter oldDelegate) {
    return oldDelegate.klines != klines || oldDelegate.crossX != crossX;
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

Future<List<List<num>>> _fetchKlinesInterval(
    String symbol, String interval) async {
  final client = await DioBinanceClient.createFromPrefs();
  final sym = _toBinanceSymbol(symbol);
  try {
    return await client.klines(sym, interval,
        limit: interval == '5m' ? 240 : 120);
  } catch (e) {
    // conservative fallback
    return _fetchKlines(symbol);
  }
}

Future<Map<String, dynamic>> _fetchTicker24h(String symbol) async {
  final client = await DioBinanceClient.createFromPrefs();
  final sym = _toBinanceSymbol(symbol);
  return client.ticker24h(sym);
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
  // If already a slash format (e.g., BTC/USD or BTC/USDT)
  if (up.contains('/')) {
    final parts = up.split('/');
    final base = parts[0];
    final quote = parts[1];
    final q = quote == 'USD' ? 'USDT' : quote;
    return base + q;
  }
  // If it already ends with USDT, keep it
  if (up.endsWith('USDT')) return up;
  // If it ends with USD (but not USDT), convert to USDT
  if (up.endsWith('USD')) return '${up.substring(0, up.length - 3)}USDT';
  return up;
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
