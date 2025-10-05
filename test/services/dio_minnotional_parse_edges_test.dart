import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parses minNotional from string, large values, and missing fields', () {
    final json = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '10.00000000'},
          ],
        },
        {
          'symbol': 'ETHUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '123456789.12345678'},
          ],
        },
        {
          'symbol': 'FOOUSDT',
          'filters': [
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.01'},
          ],
        },
      ],
    };

    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(json, 'BTCUSDT'),
      closeTo(10.0, 1e-9),
    );
    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(json, 'ETHUSDT'),
      closeTo(123456789.12345678, 1e-9),
    );
    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(json, 'BARUSDT'),
      0,
    );
    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(json, 'FOOUSDT'),
      0,
    );
  });
}
