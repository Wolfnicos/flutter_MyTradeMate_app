import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('filters zero/negative/non-numeric balances and preserves order', () {
    final balances = <Map>[
      {'asset': 'BTC', 'free': '0.00000000', 'locked': '0'}, // zero -> drop
      {'asset': 'FOO', 'free': '-0.1', 'locked': '0'}, // negative -> drop
      {
        'asset': 'BAR',
        'free': 'NaN',
        'locked': '0'
      }, // non-numeric -> 0 -> drop
      {'asset': 'USDT', 'free': '150', 'locked': '0'}, // keep
      {'asset': 'ETH', 'free': '0.1000', 'locked': '0'}, // keep
    ];

    final h = PortfolioAggregator.toHoldingsFromBalances(balances);
    expect(h.map((e) => e.asset).toList(), ['USDT', 'ETH']);

    final prices = {'ETH': 2500.0}; // USDT => 1.0 implicit
    final snap = PortfolioAggregator.compute(h, prices);
    expect(snap.totalUsdt, closeTo(400.0, 1e-9));
  });
}



