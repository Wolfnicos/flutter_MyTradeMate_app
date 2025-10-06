import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('normSymbolForTest strips spaces/slash and uppercases', () {
    final c = DioBinanceClient.fakeForTest();

    expect(c.normSymbolForTest(' btc/usdt '), 'BTCUSDT');
    expect(c.normSymbolForTest('Eth Usdt'), 'ETHUSDT');
    expect(c.normSymbolForTest('sol/UsDt'), 'SOLUSDT');
    expect(c.normSymbolForTest('ADAUSDT'), 'ADAUSDT');
  });
}

