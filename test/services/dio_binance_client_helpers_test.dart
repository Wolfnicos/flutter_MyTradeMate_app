import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('normSymbol uppercases and strips slash', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.normSymbolForTest('btc/usdt'), 'BTCUSDT');
    expect(c.normSymbolForTest('ethusdt'), 'ETHUSDT');
  });

  test('toQuery drops nulls and stringifies values', () {
    final c = DioBinanceClient.fakeForTest();
    final out = c.toQueryForTest({
      'symbol': 'BTCUSDT',
      'limit': 100,
      'optional': null,
      'price': 1234.56,
    });
    expect(out.keys, containsAll(['symbol', 'limit', 'price']));
    expect(out.containsKey('optional'), isFalse);
    expect(out['limit'], '100');
    expect(out['price'], '1234.56');
  });

  test('clampToMinNotionalForTest clamps up to threshold', () {
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 9.99, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 10, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 12.5, minNotional: 10),
      12.5,
    );
  });
}
