import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  final apiKey = const String.fromEnvironment('BINANCE_TESTNET_KEY', defaultValue: '');
  final secret = const String.fromEnvironment('BINANCE_TESTNET_SECRET', defaultValue: '');
  final enabled = apiKey.isNotEmpty && secret.isNotEmpty;

  test('REAL TESTNET: /time and /exchangeInfo', () async {
    if (!enabled) return;
    final dio = Dio(BaseOptions(baseUrl: 'https://testnet.binance.vision'));
    final t = await dio.get('/api/v3/time');
    expect(t.statusCode, 200);
  }, skip: !enabled);
}




