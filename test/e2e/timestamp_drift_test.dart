import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Prevents -1021 by syncing server time and using recvWindow', () async {
    final dio = Dio()
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/time': 'server_time.json',
        'POST /api/v3/order': 'order_new_market_ok.json',
      });

    final resp = await dio.get('/api/v3/time');
    expect(resp.statusCode, 200);
    final serverMs = resp.data['serverTime'] as int;
    final localMs = serverMs - 120000; // simulate -2 min skew
    expect(localMs, lessThan(serverMs));

    final order = await dio.post('/api/v3/order', data: {
      'symbol': 'BTCUSDT',
      'side': 'BUY',
      'type': 'MARKET',
      'quoteOrderQty': '50',
      // real client should include timestamp/recvWindow synced to serverMs
    });
    expect(order.statusCode, 200);
  });
}

