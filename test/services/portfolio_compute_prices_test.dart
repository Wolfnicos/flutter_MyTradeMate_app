import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('compute totals with mixed assets uses price map and ignores unknowns', () {
    final h = [
      const Holding('USDT', 100, 1.0),
      const Holding('BTC', 0.01, 0.0), // to be filled by map
      const Holding('UNKNOWN', 5, 0.0),
    ];
    final prices = {'BTC': 60000.0}; // UNKNOWN absent -> 0
    final snap = PortfolioAggregator.compute(h, prices);
    // total = 100 + 0.01*60000 + 5*0 = 100 + 600 = 700
    expect(snap.totalUsdt, closeTo(700.0, 1e-9));
    final btc = snap.holdings.firstWhere((x) => x.asset == 'BTC');
    expect(btc.priceUsdt, 60000.0);
  });
}


