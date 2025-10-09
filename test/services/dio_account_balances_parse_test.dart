import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseBalancesForTest parses strings/numbers and filters zeros', () {
    final payload = {
      'balances': [
        {'asset': 'USDT', 'free': '10', 'locked': '0'},
        {'asset': 'BTC', 'free': 0.001, 'locked': '0'},
        {'asset': 'FOO', 'free': '0', 'locked': '0'},
      ]
    };
    final c = DioBinanceClient.fakeForTest();
    final b = c.parseBalancesForTest(Map<String, dynamic>.from(payload));
    expect(b.length, 2);
    expect(b.first['asset'], 'USDT');
    expect(b.last['asset'], 'BTC');
  });
}



