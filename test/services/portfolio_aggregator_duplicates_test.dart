import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('duplicate assets accumulate correctly into the USDT total', () {
    final holdings = <Holding>[
      const Holding('BTC', 0.002, 0.0),
      const Holding('USDT', 50.0, 1.0),
      const Holding('BTC', 0.003, 0.0),
    ];

    final prices = <String, double>{'BTC': 60000.0};

    final snap = PortfolioAggregator.compute(holdings, prices);

    expect(snap.totalUsdt, closeTo(350.0, 1e-9));

    final btcPositions = snap.holdings.where((h) => h.asset == 'BTC').toList();
    expect(btcPositions.length, 2);
    expect(btcPositions[0].priceUsdt, 60000.0);
    expect(btcPositions[1].priceUsdt, 60000.0);
  });
}



