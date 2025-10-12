import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';
import '../mocks/binance_mocks.dart';

@Tags(['ws'])
void main() {
  test('reconnects bounded with tiny backoff', () async {
    for (var run = 0; run < 3; run++) {
      final s = await ScriptedEventSource.fromFixture(
        'test/fixtures/binance_ws/reconnect_then_resume.json',
      );
      s.reconnectBackoff = const Duration(milliseconds: 40);

      final svc = MarketDataServiceImpl(
        env: TradeEnv.testnet,
        eventSource: s,
        throttleInterval: const Duration(milliseconds: 5),
        gapThreshold: const Duration(milliseconds: 50),
        gapPollInterval: const Duration(milliseconds: 25),
        reconnectBackoff: const [
          Duration(milliseconds: 40),
          Duration(milliseconds: 40)
        ],
        maxReconnects: 2,
        jitterBackoff: false,
      );

      await svc.startSymbol('BTCUSDT');
      await s.drained;
      await svc.dispose();
      await s.close();

      expect(s.connectionAttempts, lessThanOrEqualTo(2),
          reason: 'WS should reconnect at most twice under scripted failures.');
    }
  }, timeout: const Timeout(Duration(seconds: 8)));
}
