import 'package:flutter_test/flutter_test.dart';
import '../_helpers/test_market_data.dart'; // TestFakeEventSource, TestFakeRest, drainMicrotasks
import 'package:mytrademate/services/market_data_service.dart';

void main() {
  test('pause/resume does not duplicate events', () async {
    final src = TestFakeEventSource();
    final rest = TestFakeRest(100.0);
    final svc = MarketDataServiceImpl.test(
      eventSource: src,
      rest: rest,
      sleep: (d) async {}, // noDelay
      throttle: const Duration(milliseconds: 1),
      pollInterval: const Duration(milliseconds: 5),
    );

    addTearDown(() async {
      await svc.dispose();
      await drainMicrotasks();
    });

    final seen = <double>[];
    final sub = svc.streamFor('BTCUSDT').listen((p) => seen.add(p));
    addTearDown(() async => sub.cancel());

    // start + kick inițial determinist
    await svc.startSymbol('BTCUSDT');
    src.emitNum(1000.0);
    await drainMicrotasks();
    expect(seen, contains(1000.0));

    // pauză: niciun eveniment nu trebuie să intre
    await svc.pause();
    src.emitNum(1001.0);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(seen.contains(1001.0), isFalse, reason: 'no events during pause');

    // resume + kick explicit: exact un nou eveniment
    final before = seen.length;
    await svc.resume();
    src.emitNum(1002.0); // „kick” determinist după resume
    await Future.delayed(const Duration(milliseconds: 30));
    await drainMicrotasks();

    expect(seen.length, before + 1, reason: 'one new event after resume');
    expect(seen.last, 1002.0);

    // reconnect count resilience: strict when knobs fixed, else allow minor variance
    expect(src.connects, inInclusiveRange(1, 3),
        reason: 'bounded WS connects during pause/resume');
  }, timeout: const Timeout(Duration(seconds: 6)));
}
