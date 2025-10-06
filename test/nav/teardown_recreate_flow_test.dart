import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_stream_manager.dart';

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

  @override
  Future<void> close() async {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      await _controllers.last.close();
    }
  }

  void emit(String j) {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      _controllers.last.add(j);
    }
  }
}

Future<void> noDelay(Duration _) async {}

void main() {
  test('Recreate attaches once and detaches cleanly (no duplicates)', () async {
    final src = FakeSource();
    final pm = PriceStreamManager();
    final s1 = await pm.attach('ETHUSDT', source: src, sleep: noDelay);
    final sub1 = s1.listen((_) {});
    expect(src.connects, 1);

    // second attach (another screen)
    final s2 = await pm.attach('ETHUSDT', source: src, sleep: noDelay);
    final sub2 = s2.listen((_) {});
    expect(src.connects, 1); // same underlying stream

    await sub1.cancel();
    await pm.detach('ETHUSDT'); // ref-- (still one remains)
    expect(src.connects, 1);

    await sub2.cancel();
    await pm.detach('ETHUSDT'); // ref-->0 => closed
    // optional: check that future attach reconnects
    await pm.attach('ETHUSDT', source: src, sleep: noDelay);
    expect(src.connects, 2);
  });
}
