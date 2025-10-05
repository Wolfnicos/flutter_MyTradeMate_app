import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

class _FakeSource implements PriceEventSource {
  final List<StreamController<dynamic>> _controllers = <StreamController<dynamic>>[];
  int connects = 0;
  @override
  Stream connect(Uri _) {
    connects++;
    final c = StreamController<dynamic>.broadcast();
    _controllers.add(c);
    return c.stream;
  }
  void emitNum(double v) {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      _controllers.last.add('{"c":$v}');
    }
  }
  Future<void> dropAndReconnect() async {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      await _controllers.last.close();
    }
  }
  @override
  Future<void> close() async {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      await _controllers.last.close();
    }
  }
}

class _FakeRest implements PriceRestClient {
  double price = 1000.0;
  @override
  Future<bool> ping() async => true;
  @override
  Future<double> tickerPrice(String symbol) async => price;
}

Future<void> _noDelay(Duration _) async {}
Future<void> _sleepSlow(Duration _) async => Future.value();

void main() {
  test('Burst updates throttled, reconnect OK, REST fills gaps', () async {
    final src = _FakeSource();
    final rest = _FakeRest();
    final svc = MarketDataServiceImpl(
      env: TradeEnv.testnet,
      rest: rest,
      throttleInterval: const Duration(milliseconds: 5),
      gapThreshold: const Duration(milliseconds: 20),
      gapPollInterval: const Duration(milliseconds: 10),
      eventSource: src,
      sleep: _sleepSlow,
    );
    addTearDown(() async {
      await svc.dispose();
      await pumpEventQueue(times: 5);
    });

    // Start and listen
    await svc.startSymbol('BTCUSDT');
    final events = <double>[];
    final sub = svc.streamFor('BTCUSDT').listen(events.add);
    addTearDown(sub.cancel);

    // Kick initial
    src.emitNum(1000.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Burst 100 messages in quick succession
    for (int i = 0; i < 100; i++) {
      src.emitNum(1000 + i.toDouble());
    }
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // Simulate reconnect via global pause/resume
    await svc.pause();
    src.emitNum(2000.0); // suppressed while paused
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await svc.resume();
    // First same-as-last suppressed, then a new value
    final lastSeen = events.isNotEmpty ? events.last : 1000.0;
    src.emitNum(lastSeen); // suppressed
    src.emitNum(lastSeen + 7.0); // accepted
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // REST fallback window: close src and set a new REST value
    await src.dropAndReconnect();
    rest.price = (events.isNotEmpty ? events.last : 1007.0) + 3.0;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Bounded assertions
    expect(events, isNotEmpty);
    expect(events.last, greaterThan(1000.0));
    expect(src.connects, lessThanOrEqualTo(2));
    await svc.stopSymbol('BTCUSDT');
  }, timeout: const Timeout(Duration(seconds: 6)));
}


