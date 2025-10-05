import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseTickerPriceForTest handles num and string', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.parseTickerPriceForTest({'price': 1234.56}), 1234.56);
    expect(c.parseTickerPriceForTest({'price': '789.01'}), 789.01);
    expect(c.parseTickerPriceForTest({'c': '100.5'}), 100.5);
  });

  test('parseKlinesForTest coerces to List<List<num>>', () {
    final c = DioBinanceClient.fakeForTest();
    final raw = [
      [1, '2', '3', 4, '5', 6],
      ['7', 8, 9, '10', 11, '12'],
    ];
    final out = c.parseKlinesForTest(raw);
    expect(out.length, 2);
    expect(out[0][1], '2');
    expect(out[1][3], '10');
  });
}


