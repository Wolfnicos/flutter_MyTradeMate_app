import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseTickerPrice accepts num or string', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.parseTickerPriceForTest({'price': 1234.5}), 1234.5);
    expect(c.parseTickerPriceForTest({'price': '1234.50'}), 1234.5);
    expect(c.parseTickerPriceForTest({'c': '999.9'}), 999.9);
  });

  test('parseKlines casts to list of list', () {
    final c = DioBinanceClient.fakeForTest();
    final raw = [
      [0,0,0,0, '1000.0', 0,0,0,0,0,0,0],
      [0,0,0,0, 1001.0,   0,0,0,0,0,0,0],
    ];
    final kl = c.parseKlinesForTest(raw);
    expect(kl.length, 2);
  expect(kl.first[4], '1000.0');
  });
}


