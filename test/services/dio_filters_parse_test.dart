import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  final payload = {
    'symbols': [
      {
        'symbol': 'BTCUSDT',
        'filters': [
          {'filterType': 'PRICE_FILTER', 'tickSize': '0.10'},
          {'filterType': 'LOT_SIZE', 'stepSize': '0.00001000'},
        ],
      },
      {
        'symbol': 'ETHUSDT',
        'filters': [
          {'filterType': 'LOT_SIZE', 'stepSize': 0.001},
          {'filterType': 'PRICE_FILTER', 'tickSize': '0.01'},
        ],
      },
      {
        'symbol': 'FOOUSDT',
        'filters': [
          {'filterType': 'NOT_RELEVANT', 'x': 1},
        ],
      },
    ]
  };

  test('tickSizeFromExchangeInfoForTest', () {
    expect(DioBinanceClient.tickSizeFromExchangeInfoForTest(payload, 'BTCUSDT'),
        closeTo(0.10, 1e-12));
    expect(DioBinanceClient.tickSizeFromExchangeInfoForTest(payload, 'ETHUSDT'),
        closeTo(0.01, 1e-12));
    expect(DioBinanceClient.tickSizeFromExchangeInfoForTest(payload, 'BARUSDT'),
        0.0);
    expect(DioBinanceClient.tickSizeFromExchangeInfoForTest(payload, 'FOOUSDT'),
        0.0);
  });

  test('stepSizeFromExchangeInfoForTest', () {
    expect(DioBinanceClient.stepSizeFromExchangeInfoForTest(payload, 'BTCUSDT'),
        closeTo(0.00001, 1e-12));
    expect(DioBinanceClient.stepSizeFromExchangeInfoForTest(payload, 'ETHUSDT'),
        closeTo(0.001, 1e-12));
    expect(DioBinanceClient.stepSizeFromExchangeInfoForTest(payload, 'BARUSDT'),
        0.0);
    expect(DioBinanceClient.stepSizeFromExchangeInfoForTest(payload, 'FOOUSDT'),
        0.0);
  });
}
