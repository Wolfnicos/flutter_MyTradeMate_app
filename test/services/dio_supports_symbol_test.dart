import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('supportsSymbolForTest matches normalized symbols', () {
    final listed = ['BTCUSDT', 'ethusdt', 'AdaUsdt'];
    final c = DioBinanceClient.fakeForTest();
    expect(c.supportsSymbolForTest(listed, 'btc/usdt'), isTrue);
    expect(c.supportsSymbolForTest(listed, 'ETH/USDT'), isTrue);
    expect(c.supportsSymbolForTest(listed, 'SOLUSDT'), isFalse);
  });

  test('toQueryForTest stringifies bool/int/double and drops null', () {
    final c = DioBinanceClient.fakeForTest();
    final out = c.toQueryForTest({
      'a': null,
      'b': 1,
      'c': 1.25,
      'd': true,
      'e': 'ok',
    });
    expect(out.containsKey('a'), isFalse);
    expect(out['b'], '1');
    expect(out['c'], '1.25');
    expect(out['d'], 'true');
    expect(out['e'], 'ok');
  });
}
