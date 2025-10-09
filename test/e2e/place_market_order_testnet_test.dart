import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Place MARKET on Testnet (FILLED)', () async {
    final dio = Dio()
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/time': 'server_time.json',
        'POST /api/v3/order': 'order_new_market_ok.json',
      });
    final r = await dio.post('/api/v3/order', data: {
      'symbol': 'BTCUSDT',
      'side': 'BUY',
      'type': 'MARKET',
      'quoteOrderQty': '50'
    });
    expect(r.statusCode, 200);
    expect(r.data['status'], 'FILLED');
  });
}


