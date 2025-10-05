import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mytrademate/services/market_data_service.dart';
import '../_helpers/test_market_data.dart';

void main() {
  test('UI emissions respect Hz cap', () async {
    final src = TestFakeEventSource();
    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: TestFakeRest(1000),
      sleep: (d) async {},
      throttle: const Duration(milliseconds: 200),
      pollInterval: const Duration(days: 1),
    );

    final symbol = 'BTCUSDT';
    final events = <double>[];
    final sub = svc.prices(symbol).listen((v) => events.add(v));
    await svc.startSymbol(symbol);

    fakeAsync((fa) {
      for (var i = 0; i < 50; i++) {
        src.emitNum(1000.0 + i.toDouble());
        fa.elapse(const Duration(milliseconds: 20));
      }
      fa.elapse(const Duration(milliseconds: 250));
    });

    await sub.cancel();
    await svc.dispose();

    expect(events.length <= 6, isTrue, reason: 'UI rate should be capped near 5 Hz');
  }, timeout: const Timeout(Duration(seconds: 5)));
}


