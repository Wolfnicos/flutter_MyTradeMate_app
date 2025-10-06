import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('E2E: place market order on testnet (mock)', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://testnet.binance.vision'));
    dio.httpClientAdapter = MockBinanceAdapter({
      'GET /api/v3/time': 'server_time.json',
      'GET /api/v3/exchangeInfo': 'exchange_info_ethusdt.json',
      'GET /api/v3/klines': 'klines_btcusdt_5m_256.json',
      'POST /api/v3/order': 'order_new_market_ok.json',
    });

    final time = await dio.get('/api/v3/time');
    expect(time.statusCode, 200);
    final order = await dio.post('/api/v3/order', data: {
      'symbol': 'BTCUSDT',
      'side': 'BUY',
      'type': 'MARKET',
      'quoteOrderQty': '50'
    });
    expect(order.statusCode, 200);
    expect(order.data['status'], anyOf('FILLED', 'PARTIALLY_FILLED', 'NEW'));
  });
}

