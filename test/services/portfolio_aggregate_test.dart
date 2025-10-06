import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('compute totals across USDT/BTC/unknown', () {
    final holdings = [
      const Holding('USDT', 50.0, 1.0),
      const Holding('BTC', 0.01, 0.0),
      const Holding('XYZ', 100.0, 0.0), // unknown → ignored
    ];
    final prices = {'BTC': 60000.0};
    final snap = PortfolioAggregator.compute(holdings, prices);
    const expected = 50.0 /*usdt*/ + 0.01 * 60000.0;
    expect(snap.totalUsdt, closeTo(expected, 1e-6));
  });
}
