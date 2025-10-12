import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseTickerPriceForTest handles num, string and c-fallback', () {
    final c = DioBinanceClient.fakeForTest();

    expect(c.parseTickerPriceForTest({'price': 1234.5}), 1234.5);
    expect(c.parseTickerPriceForTest({'price': '1234.50'}), 1234.5);
    expect(c.parseTickerPriceForTest({'c': '999.9'}), 999.9);
    expect(c.parseTickerPriceForTest({'price': '1e3'}), 1000.0);
  });
}
