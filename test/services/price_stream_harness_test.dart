import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream.dart';

class FakeSource implements PriceEventSource {
  final List<StreamController<dynamic>> _controllers = [];
  int connectCount = 0;
  bool failImmediately = false;

  @override
  Stream connect(Uri uri) {
    connectCount++;
    final c = StreamController<dynamic>();
    _controllers.add(c);
    if (failImmediately) {
      // emit error immediately -> triggers backoff without real delay
      Future.microtask(() => c.addError('boom'));
    }
    return c.stream;
  }

  void emit(dynamic v) {
    if (_controllers.isNotEmpty) {
      _controllers.last.add(v);
    }
  }

  @override
  Future<void> close() async {
    for (final c in _controllers) {
      await c.close();
    }
  }
}

Future<void> noDelay(Duration _) async {}

void main() {
  test('PriceStream backoff helpers & circuit breaker', () {
    expect(PriceStream.backoffForAttempt(1).inSeconds, 1);
    expect(PriceStream.backoffForAttempt(3).inSeconds, 5);
    expect(PriceStream.backoffForAttempt(6).inSeconds, 30);
    expect(PriceStream.shouldTripCircuit(5), false);
    expect(PriceStream.shouldTripCircuit(6), true);
  });

  test('reconnects deterministically and forwards prices', () async {
    final src = FakeSource()..failImmediately = true;
    final ps = PriceStream(symbol: 'BTCUSDT', testnet: true, source: src, sleep: noDelay);
    final values = <double>[];
    final sub = ps.prices.listen(values.add, onError: (_) {});

    // First connect fails -> backoff (no real delay) -> reconnect
    unawaited(ps.start());
    await Future.microtask(() {});

    // Disable failure, reconnection will receive data
    src.failImmediately = false;
    await Future.microtask(() {});
    await Future.microtask(() {});
    src.emit('{"c":"1000.0"}');
    await Future.microtask(() {});
    await Future.microtask(() {});
    expect(values, isNotEmpty);
    expect(values.first, 1000.0);

    await ps.close();
    await sub.cancel();
  });
}


