import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('minNotionalFromExchangeInfoForTest works regardless of filters order',
      () {
    final payload = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.10'},
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '10.00'},
            {'filterType': 'LOT_SIZE', 'stepSize': '0.00001000'},
          ],
        },
        {
          'symbol': 'ETHUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': 5},
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.01'},
          ],
        },
      ],
    };

    final btcMin =
        DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'BTCUSDT');
    final ethMin =
        DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'ETHUSDT');

    expect(btcMin, closeTo(10.0, 1e-12));
    expect(ethMin, closeTo(5.0, 1e-12));
  });
}



