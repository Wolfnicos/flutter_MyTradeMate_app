import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Test connection with invalid key -> -2015', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/account': 'error_invalid_key_2015.json',
      });
    final r = await dio.get('/api/v3/account');
    expect(r.statusCode, 400);
    expect(r.data['code'], -2015);
  });
}
