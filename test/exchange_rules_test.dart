import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('ExchangeRules parses filters and rounds correctly', () {
    final info = {
      'symbols': [
        {
          'symbol': 'BTCUSDT',
          'filters': [
            {'filterType': 'PRICE_FILTER', 'tickSize': '0.10'},
            {'filterType': 'LOT_SIZE', 'stepSize': '0.00010000'},
            {'filterType': 'MIN_NOTIONAL', 'minNotional': '5.0'},
          ],
        },
      ],
    };

    final r = ExchangeRules.fromExchangeInfo(info, 'BTCUSDT');
    // With double parsing, tickSize '0.10' becomes 0.1 => scale 1
    expect(r.priceScale, 1);
    expect(r.qtyScale, 4);
    expect(r.minNotional, 5.0);

    expect(r.roundPrice(123.456), 123.4);
    expect(r.roundQty(0.123456), 0.1234);
    expect(r.validateNotional(price: 1.0, qty: 4.0), isNotNull);
    expect(r.validateNotional(price: 1.0, qty: 6.0), isNull);
  });
}
