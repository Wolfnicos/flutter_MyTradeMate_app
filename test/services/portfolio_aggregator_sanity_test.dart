import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('empty holdings -> total 0', () {
    final snap = PortfolioAggregator.compute(
        const <Holding>[], const <String, double>{});
    expect(snap.totalUsdt, 0.0);
    expect(snap.holdings, isEmpty);
  });

  test('only USDT -> total equals quantity (price=1)', () {
    final h = [const Holding('USDT', 321.45, 1.0)];
    final snap = PortfolioAggregator.compute(h, const {});
    expect(snap.totalUsdt, closeTo(321.45, 1e-9));
    expect(snap.holdings.single.asset, 'USDT');
    expect(snap.holdings.single.priceUsdt, 1.0);
  });
}
