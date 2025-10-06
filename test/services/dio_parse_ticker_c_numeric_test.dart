import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseTickerPriceForTest uses numeric c when price missing', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.parseTickerPriceForTest({'c': 1001.2}), 1001.2);
  });
}

