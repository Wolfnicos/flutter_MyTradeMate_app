import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_stream_manager.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv;
import 'package:mytrademate/utils/throttler.dart';

/// Market data service that wraps WebSocket price streams with:
/// - throttling to protect UI
/// - REST fallback when no WS data is received for a gap threshold
/// - clean shutdown and idempotent listeners per symbol
abstract class MarketDataService {
  Stream<double> streamFor(String symbol);
  Future<void> startSymbol(String symbol);
  Future<void> stopSymbol(String symbol);
  Future<void> dispose();
  Future<void> pause();
  Future<void> resume();
  // Convenience API for UI callers
  Stream<double> prices(String symbol) => streamFor(symbol);
  Future<void> start(String symbol) => startSymbol(symbol);
  Future<void> stopIfOrphan(String symbol) => stopSymbol(symbol);
  Future<double> refreshNow(String symbol);
}

class MarketDataServiceImpl implements MarketDataService {
  final PriceStreamManager _pm;
  final PriceRestClient _rest;
  final Duration throttleInterval;
  final Duration gapThreshold;
  final Duration gapPollInterval;
  final PriceEventSource? eventSource;
  final SleepFn? sleep;

  final Map<String, _Entry> _entries = <String, _Entry>{};
  bool _paused = false;

  MarketDataServiceImpl({
    required TradeEnv env,
    PriceStreamManager? pm,
    PriceRestClient? rest,
    this.throttleInterval = const Duration(milliseconds: 50),
    this.gapThreshold = const Duration(seconds: 3),
    this.gapPollInterval = const Duration(seconds: 1),
    this.eventSource,
    this.sleep,
  })  : _pm = pm ?? PriceStreamManager(),
        _rest = rest ?? DefaultPriceRestClient(env: env);

  @visibleForTesting
  MarketDataServiceImpl.test({
    required PriceEventSource eventSource,
    required PriceRestClient rest,
    SleepFn? sleep,
    Duration throttle = const Duration(milliseconds: 5),
    Duration pollInterval = const Duration(milliseconds: 10),
  })  : _pm = PriceStreamManager(),
        _rest = rest,
        throttleInterval = throttle,
        gapThreshold = const Duration(seconds: 3),
        gapPollInterval = pollInterval,
        eventSource = eventSource,
        sleep = sleep;

  @override
  Stream<double> streamFor(String symbol) {
    final key = _norm(symbol);
    final e = _entries[key];
    if (e != null) return e.out.stream;
    // Lazily start on first access for convenience
    unawaited(startSymbol(key));
    return _ensure(key).out.stream;
  }

  @override
  Stream<double> prices(String symbol) => streamFor(symbol);

  @override
  Future<void> start(String symbol) => startSymbol(symbol);

  @override
  Future<void> stopIfOrphan(String symbol) => stopSymbol(symbol);

  @override
  Future<void> startSymbol(String symbol) async {
    final key = _norm(symbol);
    final e = _ensure(key);
    e.ref += 1;
    if (e.ref > 1) return; // already running

    await _attachWs(key, e);

    // Kick off fallback timer
    _startPoller(key, e);
  }

  @override
  Future<void> stopSymbol(String symbol) async {
    final key = _norm(symbol);
    final e = _entries[key];
    if (e == null) return;
    e.ref -= 1;
    if (e.ref > 0) return;
    await _shutdownEntry(key, e);
    _entries.remove(key);
  }

  @override
  Future<double> refreshNow(String symbol) async {
    final key = _norm(symbol);
    final e = _ensure(key);
    try {
      final p = await _rest.tickerPrice(key);
      if (!e.out.isClosed) {
        if (e.lastPrice == null || p != e.lastPrice) {
          e.lastPrice = p;
          e.out.add(p);
        }
      }
      e.lastEvent = DateTime.now();
      return p;
    } catch (_) {
      // ignore fetch errors for UI-initiated refresh
      return 0.0;
    }
  }

  @override
  Future<void> dispose() async {
    final keys = List<String>.from(_entries.keys);
    for (final k in keys) {
      final e = _entries[k]!;
      await _shutdownEntry(k, e);
    }
    _entries.clear();
  }

  @override
  Future<void> pause() async {
    if (_paused) return; // idempotent
    _paused = true;
    // per-symbol cancel subscription to avoid duplicates on resume
    for (final e in _entries.values) {
      if (e.paused) continue;
      e.paused = true;
      try { await e.ws?.cancel(); } catch (_) {}
      e.ws = null;
      try { e.timer?.cancel(); } catch (_) {}
      e.timer = null;
    }
  }

  @override
  Future<void> resume() async {
    if (!_paused) return; // idempotent
    _paused = false;
    // per-symbol re-attach if needed
    for (final entry in _entries.entries) {
      final key = entry.key;
      final e = entry.value;
      if (!e.paused) continue;
      e.paused = false;
      if (e.ws == null && !e.reconnecting) {
        await _attachWs(key, e);
      }
      if (e.timer == null && !e.disposed) {
        _startPoller(key, e);
      }
    }
  }

  Future<void> _shutdownEntry(String key, _Entry e) async {
    e.disposed = true;
    try { e.timer?.cancel(); } catch (_) {}
    try { await e.ws?.cancel(); } catch (_) {}
    try { await _pm.detach(key); } catch (_) {}
    await e.out.close();
  }

  _Entry _ensure(String key) {
    return _entries.putIfAbsent(
      key,
      () => _Entry(Throttler(throttleInterval)),
    );
  }

  Future<void> _attachWs(String key, _Entry e) async {
    if (e.out.isClosed || e.reconnecting || e.disposed) return;
    e.reconnecting = true;
    try {
      try { await e.ws?.cancel(); } catch (_) {}
      e.ws = null;

      final ws = await _pm.attach(key, source: eventSource, sleep: sleep);
      e.ws = ws.listen((v) {
        e.lastEvent = DateTime.now();
        // Throttle UI-facing emissions
        e.throttler.run(() {
          if (e.out.isClosed || _paused || e.paused || e.disposed) return;
          // anti-duplicate: suppress same value as last
          if (e.lastPrice != null && v == e.lastPrice) return;
          e.lastPrice = v;
          e.out.add(v);
        });
      }, onError: (_) async {
        if (_paused || e.paused || e.disposed) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        unawaited(_attachWs(key, e));
      }, onDone: () async {
        if (_paused || e.paused || e.disposed) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        unawaited(_attachWs(key, e));
      }, cancelOnError: true);
    } finally {
      e.reconnecting = false;
    }
  }

  void _startPoller(String key, _Entry e) {
    if (e.disposed) return;
    try { e.timer?.cancel(); } catch (_) {}
    e.timer = Timer.periodic(gapPollInterval, (t) async {
      if (_paused || e.paused || e.disposed) return;
      final last = e.lastEvent;
      if (last == null) return;
      final since = DateTime.now().difference(last);
      if (since >= gapThreshold) {
        try {
          final p = await _rest.tickerPrice(key);
          if (!e.out.isClosed) {
            if (e.lastPrice == null || p != e.lastPrice) {
              e.lastPrice = p;
              e.out.add(p);
            }
          }
          e.lastEvent = DateTime.now();
        } catch (_) {
          // ignore transient REST failures
        }
      }
    });
  }

  String _norm(String s) => s.replaceAll('/', '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

  @visibleForTesting
  int refsForTest(String symbol) => _entries[_norm(symbol)]?.ref ?? 0;
}

class _Entry {
  _Entry(this.throttler);
  final Throttler throttler;
  final StreamController<double> out = StreamController<double>.broadcast();
  StreamSubscription<double>? ws;
  Timer? timer;
  DateTime? lastEvent;
  double? lastPrice;
  int ref = 0;
  bool paused = false;
  bool reconnecting = false;
  bool disposed = false;
}

class InheritedMarketData extends InheritedWidget {
  final MarketDataService service;

  const InheritedMarketData({super.key, required this.service, required super.child});

  static InheritedMarketData? maybeOf(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<InheritedMarketData>();
    return element?.widget as InheritedMarketData?;
  }

  static InheritedMarketData of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(InheritedMarketData old) => service != old.service;
}


