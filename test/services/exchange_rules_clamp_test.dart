import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('validateNotional flags amounts below min notional', () {
    final r = ExchangeRules(
      priceScale: 2,
      qtyScale: 4,
      tickSize: 0.01,
      stepSize: 0.0001,
      minNotional: 10.0,
    );

    // Below min notional -> error string
    final err = r.validateNotional(price: 1.0, qty: 5.0);
    expect(err, isNotNull);

    // Above min notional -> ok
    final ok = r.validateNotional(price: 5.0, qty: 3.0);
    expect(ok, isNull);
  });
}
