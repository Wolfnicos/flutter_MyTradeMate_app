import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import '../mocks/binance_mocks.dart';

@Tags(['ws'])
class _DummyRest implements PriceRestClient {
  @override
  Future<bool> ping() async => true;
  @override
  Future<double> tickerPrice(String symbol) async => 1000.0;
}

void main() {
  test('reconnects bounded under burst flaps (fixture)', () async {
    final src = await ScriptedEventSource.fromFixture(
      'test/fixtures/binance_ws/reconnect_then_resume.json',
    );
    src.maxReconnects = 1;
    src.reconnectBackoff = const Duration(milliseconds: 20);

    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: _DummyRest(),
      throttle: const Duration(milliseconds: 5),
      pollInterval: const Duration(milliseconds: 25),
      gap: const Duration(milliseconds: 50),
      reconnects: const [Duration(milliseconds: 50)],
      maxReconnects: 1,
      jitterBackoff: false,
    );

    addTearDown(() async {
      await svc.dispose();
      await Future<void>.delayed(Duration.zero);
      // best-effort flush
      for (var i = 0; i < 3; i++) { await Future<void>.delayed(Duration.zero); }
    });
    addTearDown(() async {
      await src.close();
    });

    final ticks = <double>[];
    await svc.startSymbol('BTCUSDT');
    final sub = svc.streamFor('BTCUSDT').listen(ticks.add);

    // Wait until the scripted source drains all events
    await src.drained;
    await sub.cancel();
    // Flush any pending timers before asserting connects
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await Future<void>.delayed(Duration.zero);
    expect(src.connects, equals(2), reason: 'exactly one reconnect');
    // We should have seen the initial values as per fixture order
    expect(ticks.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(seconds: 8)));
}


