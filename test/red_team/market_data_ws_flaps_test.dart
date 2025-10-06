import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import '../_helpers/test_market_data.dart';
import '../mocks/binance_mocks.dart';

Future<void> _noDelay(Duration _) async {}

void main() {
  test('WS flaps: reconnects bounded and no duplicate emissions', () async {
    final script = <Map<String, dynamic>>[
      {'tick': {'c': '1000.0'}, 'delayMs': 5},
      {'close': true, 'delayMs': 20},
      {'tick': {'c': '1001.0'}, 'delayMs': 10},
      {'tick': {'c': '1015.0'}, 'delayMs': 8},
      {'end': true, 'delayMs': 1},
    ];

    final src = ScriptedEventSource(script)
      ..maxReconnects = 1
      ..reconnectBackoff = const Duration(milliseconds: 500);

    final svc = MarketDataServiceImpl.test(
        eventSource: src,
        rest: TestFakeRest(1000.0),
        sleep: _noDelay,
        throttle: const Duration(milliseconds: 5),
        pollInterval: const Duration(milliseconds: 10),
        gap: const Duration(milliseconds: 500),
        jitterBackoff: false);

    addTearDown(() async {
      await svc.dispose();
      await src.close();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await drainMicrotasks();
    });

    final emits = <double>[];
    final completer = Completer<void>();
    final sub = svc.prices('BTCUSDT').listen((p) {
      emits.add(p);
      if (emits.length >= 3 && !completer.isCompleted) completer.complete();
    }, onError: (e, s) {
      if (!completer.isCompleted) completer.completeError(e, s);
    });

    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } finally {
      await sub.cancel();
    }

    // settle a little to let any pending timers fire
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await drainMicrotasks();

    expect(emits.length, greaterThanOrEqualTo(3));
    expect((emits[0] - 1000.0).abs() < 1e-6, isTrue);
    expect((emits[1] - 1001.0).abs() < 1e-6, isTrue);
    expect(emits.any((v) => (v - 1015.0).abs() < 1e-6), isTrue);

    expect(src.connects, lessThanOrEqualTo(3));
    for (var i = 1; i < emits.length; i++) {
      expect(emits[i], isNot(emits[i - 1]));
    }
  }, timeout: const Timeout(Duration(seconds: 10)));
}


