import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mytrademate/services/price_stream.dart';

@Deprecated('Use MarketDataService')
class PriceStreamManager {
  static final PriceStreamManager _i = PriceStreamManager._();
  PriceStreamManager._();
  factory PriceStreamManager() => _i;

  final Map<String, _Entry> _map = <String, _Entry>{};
  bool _paused = false;

  Future<Stream<double>> attach(
    String symbol, {
    PriceEventSource? source,
    SleepFn? sleep,
    bool testnet = true,
  }) async {
    final key = symbol.toUpperCase();
    final existing = _map[key];
    if (existing != null) {
      existing.ref += 1;
      return existing.stream;
    }
    final ps = PriceStream(symbol: key, testnet: testnet, source: source, sleep: sleep);
    await ps.start();
    final entry = _Entry(ps);
    _map[key] = entry;
    return entry.stream;
  }

  Future<void> detach(String symbol) async {
    final key = symbol.toUpperCase();
    final e = _map[key];
    if (e == null) return;
    e.ref -= 1;
    if (e.ref <= 0) {
      await e.close();
      _map.remove(key);
    }
  }

  Future<void> pauseAll() async {
    if (_paused) return;
    _paused = true;
    for (final e in _map.values) {
      await e.pause();
    }
  }

  Future<void> resumeAll() async {
    if (!_paused) return;
    _paused = false;
    for (final e in _map.values) {
      await e.resume();
    }
  }

  /// Test-only: închide toate stream-urile și resetează starea.
  @visibleForTesting
  Future<void> resetForTest() async {
    for (final e in _map.values) {
      await e.close();
    }
    _map.clear();
    _paused = false;
  }
}

class _Entry {
  final PriceStream ps;
  int ref = 1;
  _Entry(this.ps);
  Stream<double> get stream => ps.prices;
  Future<void> close() => ps.close();
  Future<void> pause() => ps.pause();
  Future<void> resume() => ps.resume();
}


