import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream_manager.dart';
import '../mocks/binance_mocks.dart';

/// Reconnect-friendly: fiecare connect() creează un controller nou.
Future<void> noDelay(Duration _) async {}

void main() {
  testWidgets('AppLifecycle pauses/resumes streams without duplicates',
      (tester) async {
    final src = await ScriptedEventSource.fromFixture(
      'test/fixtures/binance_ws/reconnect_then_resume.json',
    );
    final pm = PriceStreamManager();
    // reset singleton ca să nu moștenim stare din alte teste
    await pm.resetForTest();

    final s = await pm.attach('BTCUSDT', source: src, sleep: noDelay);
    var count = 0;
    final sub = s.listen((_) => count++);

    // Așteaptă primul eveniment din fixture
    await tester.pump(const Duration(milliseconds: 10));
    expect(count, greaterThanOrEqualTo(1));

    // pauză deterministă
    await pm.pauseAll();
    // în pauză — contorul nu ar trebui să crească
    await tester.pump(const Duration(milliseconds: 5));
    expect(count, 1);

    // resume determinist
    await pm.resumeAll();
    // dă timp lui resume să reconecteze
    await Future.microtask(() {});
    // după resume — următorul tick din fixture trebuie să crească contorul
    await tester.pump(const Duration(milliseconds: 60));
    expect(count, greaterThanOrEqualTo(2));

    await sub.cancel();
    await pm.detach('BTCUSDT');
    // curățare
    await pm.resetForTest();
  });
}
