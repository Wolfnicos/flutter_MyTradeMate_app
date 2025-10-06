import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('minNotionalFromExchangeInfoForTest ignores symbol casing', () {
    final payload = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '10.00'},
          ],
        },
        {
          'symbol': 'AdaUsdt',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': 5},
          ],
        },
      ],
    };

    expect(
        DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'btcusdt'),
        closeTo(10.0, 1e-12));
    expect(
        DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'ADAUSDT'),
        closeTo(5.0, 1e-12));
  });
}

