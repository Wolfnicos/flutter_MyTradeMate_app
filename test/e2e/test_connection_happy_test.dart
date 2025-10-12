import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import '../support/mock_binance_adapter.dart';

void main() {
  test('Test connection (happy path)', () async {
    final dio = Dio()
      ..httpClientAdapter = MockBinanceAdapter({
        'GET /api/v3/time': 'server_time.json',
        'GET /api/v3/ping': 'ping_ok.json',
      });
    final t = await dio.get('/api/v3/time');
    final p = await dio.get('/api/v3/ping');
    expect(t.statusCode, 200);
    expect(p.statusCode, 200);
  });
}
