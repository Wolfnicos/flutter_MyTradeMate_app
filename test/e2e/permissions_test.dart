import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Keys without SPOT perms → -2015 surfaced clearly', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = MockBinanceAdapter({
      'POST /api/v3/order': 'error_invalid_key_2015.json',
    });
    final r = await dio.post('/api/v3/order');
    expect(r.statusCode, 400);
    expect(r.data['code'], -2015);
  });
}


