import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('sumUsdtForTest sums qty*price across holdings', () {
    final h = [
      const Holding('USDT', 100, 1.0),
      const Holding('BTC', 0.01, 60000.0),
    ];
    expect(sumUsdtForTest(h), closeTo(700.0, 1e-9));
  });
}
