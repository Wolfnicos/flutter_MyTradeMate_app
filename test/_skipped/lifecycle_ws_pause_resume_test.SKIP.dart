import 'package:flutter_test/flutter_test.dart';
import '../_helpers/test_market_data.dart';
import '../mocks/binance_mocks.dart';
import 'package:mytrademate/services/market_data_service.dart';

Future<void> noDelay(Duration _) async {}

void main() {
  test('pause/resume with single reconnect yields two ticks deterministically',
      () async {
    final src = await ScriptedEventSource.fromFixture(
      'test/fixtures/binance_ws/reconnect_then_resume.json',
    );
    src.reconnectBackoff = const Duration(milliseconds: 20);
    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: TestFakeRest(1000.0),
      sleep: noDelay,
      throttle: const Duration(milliseconds: 5),
      pollInterval: const Duration(milliseconds: 10),
      reconnects: const [Duration(milliseconds: 80)],
      maxReconnects: 1,
      jitterBackoff: false,
    );

    // Collect exactly two ticks deterministically
    final ticks = await svc
        .prices('BTCUSDT')
        .take(2)
        .toList()
        .timeout(const Duration(seconds: 2));
    expect(ticks, <double>[1000.0, 1001.0]);
    // Flush any pending timers before asserting connects
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await drainMicrotasks();
    expect(src.connects, equals(2)); // initial + one reconnect
    await svc.dispose();
    await drainMicrotasks();
  });
}
