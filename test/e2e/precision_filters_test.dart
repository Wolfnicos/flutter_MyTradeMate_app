import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Respects LOT_SIZE/tickSize/minNotional (ETHUSDT)', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/exchangeInfo': 'exchange_info_ethusdt.json',
        'POST /api/v3/order': 'error_precision_1013.json', // mock violation
      });

    final r = await dio.post('/api/v3/order');
    expect(r.statusCode, 400);
    expect(r.data['code'], -1013);
  });
}
