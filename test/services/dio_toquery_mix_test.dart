import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('toQueryForTest stringifies and drops nulls', () {
    final c = DioBinanceClient.fakeForTest();
    final out =
        c.toQueryForTest({'a': null, 'b': 1, 'c': 1.5, 'd': true, 'e': 'x'});
    expect(out.containsKey('a'), isFalse);
    expect(out['b'], '1');
    expect(out['c'], '1.5');
    expect(out['d'], 'true');
    expect(out['e'], 'x');
  });
}
