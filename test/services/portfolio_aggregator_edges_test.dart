import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('unknown asset price -> treated as 0; tiny qty preserved', () {
    final h = <Holding>[
      const Holding('USDT', 50.0, 1.0),
      const Holding('BTC', 0.00000001, 0.0), // completed from price map
      const Holding('FOO', 10.0, 0.0), // unknown -> 0
    ];
    final prices = <String, double>{'BTC': 60000.0};
    final snap = PortfolioAggregator.compute(h, prices);

    // total ~ 50 + 0.00000001 * 60000 = 50 + 0.0006 = 50.0006
    expect(snap.totalUsdt, closeTo(50.0006, 1e-6));
    // BTC price is completed from map
    final btc = snap.holdings.firstWhere((e) => e.asset == 'BTC');
    expect(btc.priceUsdt, 60000.0);
    // FOO remains 0 price => not contributing to total
    final foo = snap.holdings.firstWhere((e) => e.asset == 'FOO');
    expect(foo.priceUsdt, 0.0);
  });

  test('price 0 for all non-USDT -> total equals USDT only', () {
    final h = <Holding>[
      const Holding('USDT', 123.0, 1.0),
      const Holding('ETH', 1.5, 0.0),
    ];
    final prices = <String, double>{}; // none for ETH
    final snap = PortfolioAggregator.compute(h, prices);
    expect(snap.totalUsdt, 123.0);
  });
}
