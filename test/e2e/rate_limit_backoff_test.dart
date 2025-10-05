import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Handles HTTP 418 with bounded retry/backoff', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = MockBinanceAdapter({
      'GET /api/v3/time': 'server_time.json',
      'POST /api/v3/order': 'error_rate_limit_418.json', // 418 first
    });

    final resp = await dio.post('/api/v3/order', data: {
      'symbol': 'BTCUSDT','side':'BUY','type':'MARKET','quoteOrderQty':'50'
    });
    expect(resp.statusCode, 418);
  });
}


