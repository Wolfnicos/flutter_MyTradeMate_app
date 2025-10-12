import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import '../mocks/binance_mocks.dart';

class _FakeRest implements PriceRestClient {
  double price = 1000.0;
  @override
  Future<bool> ping() async => true;
  @override
  Future<double> tickerPrice(String symbol) async => price;
}

Future<void> _noDelay(Duration _) async {}
Future<void> _sleepSlow(Duration _) async => Future.value();

@Tags(['ws'])
void main() {
  test('Burst updates throttled, reconnect OK, REST fills gaps (fixture)',
      () async {
    final src = await ScriptedEventSource.fromFixture(
      'test/fixtures/binance_ws/burst_spike_gap.json',
    );
    src.reconnectBackoff = const Duration(milliseconds: 50);
    final rest = _FakeRest();
    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: rest,
      throttle: const Duration(milliseconds: 1),
      gap: const Duration(milliseconds: 500),
      pollInterval: const Duration(milliseconds: 10),
      sleep: _sleepSlow,
      reconnects: const [Duration(milliseconds: 50)],
      maxReconnects: 1,
      jitterBackoff: false,
    );
    addTearDown(() async {
      await svc.dispose();
      await pumpEventQueue(times: 5);
    });
    addTearDown(() async {
      await src.close();
    });

    // Collect exactly three ticks matching the fixture sequence
    final seen = await svc
        .prices('BTCUSDT')
        .take(3)
        .toList()
        .timeout(const Duration(seconds: 2));
    expect(seen.map((e) => e).toList(), <double>[1000.0, 1015.0, 1002.0]);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await pumpEventQueue(times: 3);
    expect(src.connects, inInclusiveRange(1, 2));
  }, timeout: const Timeout(Duration(seconds: 6)));
}
