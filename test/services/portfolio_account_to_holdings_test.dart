import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/portfolio_models.dart';

void main() {
  test('balances -> holdings filters zero balances and sets USDT @ 1.0', () {
    final balances = [
      {'asset': 'USDT', 'free': '10', 'locked': '0'},
      {'asset': 'BTC', 'free': '0.001', 'locked': '0'},
      {'asset': 'FOO', 'free': '0', 'locked': '0'}, // drop
    ];
    final h = PortfolioAggregator.toHoldingsFromBalances(balances);
    expect(h.length, 2);
    expect(h.first.asset, 'USDT');
    expect(h.first.priceUsdt, 1.0);
  });
}
