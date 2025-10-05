import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/app/lifecycle_observer.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_stream_manager.dart';

class _FakeSource implements PriceEventSource {
  final List<StreamController<dynamic>> _controllers = <StreamController<dynamic>>[];
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

Future<void> _noDelay(Duration _) async {}

void main() {
  testWidgets('AppLifecycleObserver pauses/resumes streams without duplicates', (tester) async {
    final pm = PriceStreamManager();
    addTearDown(() async => pm.resetForTest());

    final src = _FakeSource();
    final obs = AppLifecycleObserver();

    await tester.runAsync(() async {
      final s = await pm.attach('BTCUSDT', source: src, sleep: _noDelay);
      var count = 0;
      final sub = s.listen((_) => count++);

      // initial event delivered
      src.emit('{"c":"1000"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 1);

      // simulate background
      obs.didChangeAppLifecycleState(AppLifecycleState.paused);
      src.emit('{"c":"1001"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 1);

      // resume foreground
      obs.didChangeAppLifecycleState(AppLifecycleState.resumed);
      src.emit('{"c":"1002"}');
      await tester.pump(const Duration(milliseconds: 16));
      expect(count, 2);

      // clean up
      await sub.cancel();
      await pm.detach('BTCUSDT');
    });
  });
}


