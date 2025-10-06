import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('toHoldingsFromBalances preserves order and filters zero qty', () {
    final balances = <Map>[
      {'asset': 'BTC', 'free': '0.0100', 'locked': '0'},
      {'asset': 'FOO', 'free': '0', 'locked': '0'}, // filtered out
      {'asset': 'USDT', 'free': '200', 'locked': '0'},
      {'asset': 'ETH', 'free': '0.2500', 'locked': '0'},
    ];

    final h = PortfolioAggregator.toHoldingsFromBalances(balances);
    expect(h.map((e) => e.asset).toList(), ['BTC', 'USDT', 'ETH']);

    final prices = {'BTC': 60000.0, 'ETH': 2400.0}; // USDT => 1.0 in compute()
    final snap = PortfolioAggregator.compute(h, prices);
    expect(snap.totalUsdt, closeTo(1400.0, 1e-9));
    expect(snap.holdings.map((e) => e.asset).toList(), ['BTC', 'USDT', 'ETH']);
  });
}

