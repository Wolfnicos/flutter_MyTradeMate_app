import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_stream_manager.dart';

/// Reconnect-friendly: fiecare connect() creează un controller nou.
class FakeSource implements PriceEventSource {
  final List<StreamController<dynamic>> _controllers = [];
  int connects = 0;
  @override
  Stream connect(Uri uri) {
    connects++;
    final c = StreamController<dynamic>.broadcast();
    _controllers.add(c);
    return c.stream;
  }
  void emit(String json) {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      _controllers.last.add(json);
    }
  }
  @override
  Future<void> close() async {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      await _controllers.last.close();
    }
  }
}

Future<void> noDelay(Duration _) async {}

void main() {
  testWidgets('AppLifecycle pauses/resumes streams without duplicates', (tester) async {
    final src = FakeSource();
    final pm = PriceStreamManager();
    // reset singleton ca să nu moștenim stare din alte teste
    await pm.resetForTest();

    final s = await pm.attach('BTCUSDT', source: src, sleep: noDelay);
    var count = 0;
    final sub = s.listen((_) => count++);

    // înainte de pauză — emit și verifică
    src.emit('{"c":"1000.0"}');
    await tester.pump();
    expect(count, 1);

    // pauză deterministă
    await pm.pauseAll();
    // emit în pauză — nu trebuie să crească
    src.emit('{"c":"1001.0"}');
    await tester.pump();
    expect(count, 1);

    // resume determinist
    await pm.resumeAll();
    // dă timp lui resume să reconecteze
    await Future.microtask(() {});
    // emit după resume — trebuie să numere încă o dată
    src.emit('{"c":"1002.0"}');
    await tester.pump();
    expect(count, 2);

    await sub.cancel();
    await pm.detach('BTCUSDT');
    // curățare
    await pm.resetForTest();
  });
}


