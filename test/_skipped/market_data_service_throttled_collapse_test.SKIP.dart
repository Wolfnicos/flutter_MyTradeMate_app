import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import '../mocks/binance_mocks.dart';
import '../_helpers/test_market_data.dart';

Future<void> _noDelay(Duration _) async {}

void main() {
  test('Throttle 50ms collapses burst: leading-edge emits per window', () async {
    final src = await ScriptedEventSource.fromFixture(
      'test/fixtures/binance_ws/burst_throttled.json',
    );

    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: TestFakeRest(1000.0),
      sleep: _noDelay,
      throttle: const Duration(milliseconds: 50),
      pollInterval: const Duration(milliseconds: 10),
      gap: const Duration(milliseconds: 500),
      reconnects: const [Duration(milliseconds: 80)],
      maxReconnects: 1,
      jitterBackoff: false,
    );

    // Expect two emissions: leading-edge of first window → 1000.0, then 1002.0 after 60ms
    final emits = await svc.prices('BTCUSDT')
        .take(2)
        .toList()
        .timeout(const Duration(seconds: 2));

    expect((emits[0] - 1000.0).abs() < 1e-9, isTrue);
    expect((emits[1] - 1002.0).abs() < 1e-9, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await drainMicrotasks();
    await svc.dispose();
  }, timeout: const Timeout(Duration(seconds: 4)));
}


