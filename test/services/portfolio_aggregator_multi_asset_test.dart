import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('compute handles multiple assets with mixed price availability', () {
    final holdings = <Holding>[
      const Holding('USDT', 200.0, 1.0),
      const Holding('BTC', 0.005, 0.0),
      const Holding('ETH', 0.25, 0.0),
      const Holding('FOO', 10.0, 0.0),
    ];

    final prices = <String, double>{
      'BTC': 60000.0,
      'ETH': 2400.0,
    };

    final snap = PortfolioAggregator.compute(holdings, prices);

    expect(snap.totalUsdt, closeTo(1100.0, 1e-9));

    final btc = snap.holdings.firstWhere((h) => h.asset == 'BTC');
    final eth = snap.holdings.firstWhere((h) => h.asset == 'ETH');
    final foo = snap.holdings.firstWhere((h) => h.asset == 'FOO');
    expect(btc.priceUsdt, 60000.0);
    expect(eth.priceUsdt, 2400.0);
    expect(foo.priceUsdt, 0.0);
  });
}


