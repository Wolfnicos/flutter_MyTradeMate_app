import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('toQueryForTest preserves only primitives and ignores nested', () {
    final c = DioBinanceClient.fakeForTest();
    final out = c.toQueryForTest({'b': 2, 'a': 1, 'x': {'n': 1}, 'y': [1, 2], 's': 'ok'});
    expect(out.keys, containsAll(['a', 'b', 's']));
    expect(out.containsKey('x'), isFalse);
    expect(out.containsKey('y'), isFalse);
  });
}


