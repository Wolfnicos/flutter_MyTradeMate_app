import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('minNotionalFromExchangeInfoForTest extracts numeric/string minNotional', () {
    final json = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.10'},
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '10.0'},
          ],
        },
      ],
    };
    final v = DioBinanceClient.minNotionalFromExchangeInfoForTest(json, 'BTCUSDT');
    expect(v, 10.0);

    final json2 = {
      'symbols': [
        {
          'symbol': 'ETHUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': 5},
          ],
        },
      ],
    };
    final v2 = DioBinanceClient.minNotionalFromExchangeInfoForTest(json2, 'ETHUSDT');
    expect(v2, 5);
  });
}


