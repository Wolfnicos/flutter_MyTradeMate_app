import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:web_socket_channel/io.dart';

typedef SleepFn = Future<void> Function(Duration);

/// Interfață injectabilă pentru sursa de evenimente preț (determinist în teste).
abstract class PriceEventSource {
  Stream<dynamic> connect(Uri uri);
  Future<void> close();
}

/// Implementarea reală (WebSocket Binance).
class RealPriceEventSource implements PriceEventSource {
  IOWebSocketChannel? _ch;
  @override
  Stream<dynamic> connect(Uri uri) {
    _ch = IOWebSocketChannel.connect(uri.toString());
    return _ch!.stream;
  }

  @override
  Future<void> close() async {
    await _ch?.sink.close();
  }
}

class PriceStream {
  final String symbol;      // ex: BTCUSDT
  final bool testnet;       // true => testnet.binance.vision
  final Duration reconnectDelay;
  final PriceEventSource _source;
  final SleepFn _sleep;

  final _controller = StreamController<double>.broadcast();
  int _retries = 0;
  bool _manuallyClosed = false;
  bool _paused = false;
  StreamSubscription? _sub;

  PriceStream({
    required this.symbol,
    required this.testnet,
    this.reconnectDelay = const Duration(seconds: 2),
    PriceEventSource? source,
    SleepFn? sleep,
  })  : _source = source ?? RealPriceEventSource(),
        _sleep = sleep ?? Future.delayed;

  Stream<double> get prices => _controller.stream;

  Future<void> start() async {
    if (_paused) return;
    await _connect();
  }

  /// Oprește conexiunea, păstrând controller-ul și subscriberii existenți.
  Future<void> pause() async {
    _paused = true;
    _manuallyClosed = true; // oprește reconectările
    try { await _sub?.cancel(); } catch (_) {}
    try { await _source.close(); } catch (_) {}
    _sub = null;
  }

  /// Reia conexiunea pe același controller (subscriberii rămân valizi).
  Future<void> resume() async {
    if (!_paused) return;
    if (_controller.isClosed) return;
    _paused = false;
    _manuallyClosed = false;
    _retries = 0;
    await _connect();
  }

  @visibleForTesting
  static Duration backoffForAttempt(int attempt, {Duration max = const Duration(seconds: 30)}) {
    final table = <int, int>{1: 1, 2: 2, 3: 5, 4: 10, 5: 20};
    final secs = table[attempt] ?? 30;
    final d = Duration(seconds: secs);
    return d > max ? max : d;
  }

  @visibleForTesting
  static bool shouldTripCircuit(int consecutiveFailures, {int maxFailures = 6}) {
    return consecutiveFailures >= maxFailures;
  }

  Future<void> _connect() async {
    final sym = symbol.toLowerCase();
    final uri = testnet
        ? Uri.parse('wss://testnet.binance.vision/ws/$sym@miniTicker')
        : Uri.parse('wss://stream.binance.com:9443/ws/$sym@miniTicker');

    final stream = _source.connect(uri);
    _sub = stream.listen(
      (event) {
        try {
          final data = json.decode(event);
          final raw = (data is Map)
              ? (data['c'] ?? (data['data'] != null ? data['data']['c'] : null))
              : null;
          final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
          if (v != null && !_controller.isClosed) {
            _controller.add(v);
            _retries = 0; // reset on good data
          }
        } catch (_) {}
      },
      onDone: () async {
        if (_manuallyClosed) return;
        if (_paused) return; // dacă e pauzat, nu reconecta
        await _scheduleReconnectWithBackoff();
      },
      onError: (_, __) async {
        if (_manuallyClosed) return;
        if (_paused) return; // dacă e pauzat, nu reconecta
        await _scheduleReconnectWithBackoff();
      },
      cancelOnError: true,
    );
  }

  Future<void> _scheduleReconnectWithBackoff() async {
    _disconnect();
    _retries += 1;
    if (shouldTripCircuit(_retries)) {
      if (!_controller.isClosed) {
        _controller.addError('PriceStream circuit open: $_retries failures');
      }
      await close();
      return;
    }
    final delay = backoffForAttempt(_retries);
    await _sleep(delay);
    if (!_manuallyClosed && !_controller.isClosed) {
      await _connect();
    }
  }

  void _disconnect() {
    // Intentionally do not close the source on transient disconnects to
    // allow deterministic reconnection in tests. The source is closed in
    // close()/dispose().
  }

  void dispose() {
    _disconnect();
    _controller.close();
  }

  void stop() {
    dispose();
  }

  Future<void> close() async {
    _manuallyClosed = true;
    _paused = false;
    try { await _sub?.cancel(); } catch (_) {}
    try { await _source.close(); } catch (_) {}
    _sub = null;
    await _controller.close();
  }
}