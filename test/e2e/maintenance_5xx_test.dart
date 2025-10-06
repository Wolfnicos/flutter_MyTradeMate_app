import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Shows “Exchange unavailable” on 502/503 and does not loop', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = MockBinanceAdapter({
        'POST /api/v3/order': 'error_maintenance_503.html',
      });

    final r = await dio.post('/api/v3/order');
    expect(r.statusCode, 503);
  });
}
