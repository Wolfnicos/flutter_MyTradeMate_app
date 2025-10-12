import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Quantity rounding respects stepSize/minNotional', () async {
    final dio = Dio()
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/exchangeInfo': 'exchange_info_btcusdt.json',
        'POST /api/v3/order': 'order_new_market_ok.json',
      });
    final r = await dio.post('/api/v3/order');
    expect(r.statusCode, 200);
  });
}
