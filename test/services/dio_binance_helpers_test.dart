import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  test('normSymbolForTest normalizes correctly', () {
    final c = DioBinanceClient(env: TradeEnv.testnet);
    expect(c.normSymbolForTest('btc/usdt'), 'BTCUSDT');
    expect(c.normSymbolForTest(' ethusdt '), 'ETHUSDT');
  });

  test('toQueryForTest filters nulls and stringifies', () {
    final c = DioBinanceClient(env: TradeEnv.testnet);
    final q = c.toQueryForTest({'a': 1, 'b': null, 'sp ace': 'x y'});
    expect(q.keys, containsAll(['a', 'sp ace']));
    expect(q.containsKey('b'), isFalse);
    expect(q['a'], '1');
    expect(q['sp ace'], 'x y');
  });

  test('clampToMinNotionalForTest clamps up to threshold', () {
    expect(
        DioBinanceClient.clampToMinNotionalForTest(quote: 5, minNotional: 10),
        10);
    expect(
        DioBinanceClient.clampToMinNotionalForTest(quote: 12, minNotional: 10),
        12);
  });
}
