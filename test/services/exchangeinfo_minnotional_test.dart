import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('minNotionalFromExchangeInfoForTest parses string/num and falls back', () {
    final payload = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.10'},
            {'filterType': 'LOT_SIZE', 'stepSize': '0.00001000'},
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '10.00'},
          ],
        },
        {
          'symbol': 'ETHUSDT',
          'filters': [
            {'filterType': 'MIN_NOTIONAL', 'minNotional': 5.0},
          ],
        },
      ],
    };

    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'BTCUSDT'),
      10.0,
    );
    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'ETHUSDT'),
      5.0,
    );
    // simbol inexistent → fallback 0
    expect(
      DioBinanceClient.minNotionalFromExchangeInfoForTest(payload, 'FOOUSD'),
      0,
    );
  });

  test('clampToMinNotionalForTest clamps below threshold and keeps above', () {
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 9.99, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 10, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 12.34, minNotional: 10),
      12.34,
    );
  });
}


