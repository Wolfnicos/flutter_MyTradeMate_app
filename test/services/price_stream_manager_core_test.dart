// test/services/price_stream_manager_core_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream_manager.dart';
import 'package:mytrademate/services/price_stream.dart';

class _FakeSource implements PriceEventSource {
  final _controllers = <StreamController<dynamic>>[];
  @override
  Stream connect(Uri _) {
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

Future<void> _noDelay(Duration _) async {}

void main() {
  testWidgets('attach → pauseAll → resumeAll delivers events once', (tester) async {
    final pm = PriceStreamManager();
    final src = _FakeSource();
    addTearDown(() async => pm.resetForTest());
    await tester.runAsync(() async {
      final s = await pm.attach('BTCUSDT', source: src, sleep: _noDelay);
      var count = 0;
      final sub = s.listen((_) => count++);

      src.emit('{"c":"1000"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 1);

      await pm.pauseAll();
      src.emit('{"c":"1001"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 1);

      await pm.resumeAll();
      src.emit('{"c":"1002"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 2);

      await sub.cancel();
      await pm.detach('BTCUSDT');
    });
  });

  testWidgets('detach unsubscribes; reattach yields fresh stream', (tester) async {
    final pm = PriceStreamManager();
    final src = _FakeSource();
    addTearDown(() async => pm.resetForTest());
    await tester.runAsync(() async {
      final s1 = await pm.attach('ETHUSDT', source: src, sleep: _noDelay);
      var c1 = 0;
      final sub1 = s1.listen((_) => c1++);
      src.emit('{"c":"10"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(c1, 1);

      await pm.detach('ETHUSDT');
      src.emit('{"c":"11"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(c1, 1);

      final s2 = await pm.attach('ETHUSDT', source: src, sleep: _noDelay);
      var c2 = 0;
      final sub2 = s2.listen((_) => c2++);
      src.emit('{"c":"12"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(c2, 1);

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}


