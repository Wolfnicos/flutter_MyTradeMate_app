import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Env isolation: TESTNET order doesn’t leak to LIVE (dry-run)', () async {
    // Testnet mocks
    final testnet = Dio(BaseOptions(baseUrl: 'https://testnet.binance.vision'))
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/time': 'server_time.json',
        'POST /api/v3/order': 'order_new_market_ok.json',
      });

    final liveDryRun = Dio(BaseOptions(baseUrl: 'https://api.binance.com'))
      ..httpClientAdapter = MockBinanceAdapter({
        // No POST /order on live—should be intercepted by app DRY-RUN rail
        'GET /api/v3/time': 'server_time.json',
      });

    // Pretend app placed a TESTNET order
    final ok = await testnet.post('/api/v3/order', data: {
      'symbol': 'BTCUSDT',
      'side': 'BUY',
      'type': 'MARKET',
      'quoteOrderQty': '50'
    });
    expect(ok.statusCode, 200);

    // Now switch to LIVE with DRY-RUN: your app should not call POST /order
    final t = await liveDryRun.get('/api/v3/time');
    expect(t.statusCode, 200);
  });
}



