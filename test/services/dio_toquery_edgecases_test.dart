import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('toQueryForTest drops nulls, stringifies types and keeps bools', () {
    final c = DioBinanceClient.fakeForTest();
    final out = c.toQueryForTest({
      'symbol': 'BTCUSDT',
      'limit': 100,
      'recvWindow': null,
      'strict': true,
      'price': 1234.5,
    });
    expect(out.containsKey('recvWindow'), isFalse);
    expect(out['limit'], '100');
    expect(out['price'], '1234.5');
    expect(out['strict'], 'true');
  });
}



