import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';
import 'package:mytrademate/services/paper_broker.dart';

void main() {
  test('Trailing stop follows highs and triggers once on drop',
      timeout: const Timeout(Duration(seconds: 6)), () async {
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 10.0,
      qtyStep: 0.000001,
      priceTick: 0.01,
    );
    final cfg = PaperBrokerConfig(
      makerFeeBps: 0.5,
      takerFeeBps: 1.0,
      rulesBySymbol: {'BTCUSDT': rules},
    );
    final broker = PaperBroker(cfg);

    // Seed initial price and open a small long position at market.
    broker.tick('BTCUSDT', 1000.00);
    final buyMkt = broker.place(PaperOrderReq.market(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      quantity: 0.010000,
    )) as PaperOrder;
    expect(
        buyMkt.status, anyOf(OrderStatus.filled, OrderStatus.partiallyFilled));

    // Place a trailing stop SELL with distance 5.00 USDT (~0.5% at 1000).
    final ts = broker.place(PaperOrderReq.trailingStopSell(
      symbol: 'BTCUSDT',
      quantity: 0.010000,
      trailAmount: 5.00, // stored in stopPrice
    )) as PaperOrder;

    // Price rises; trailPeak should follow highs (via candles high)
    broker.tick('BTCUSDT', 1005.00, high: 1005.00, low: 1004.50);
    broker.tick('BTCUSDT', 1008.00, high: 1008.00, low: 1006.00);
    broker.tick('BTCUSDT', 1012.00, high: 1012.00, low: 1010.00);

    // Not yet triggered: drop, but not below peak - distance (1012 - 5 = 1007)
    broker.tick('BTCUSDT', 1007.50, high: 1008.00, low: 1007.20);
    expect(ts.status, isNot(OrderStatus.filled));

    // Cross trigger level with wick: low <= 1007 triggers; executes next tick at market
    broker.tick('BTCUSDT', 1006.80, high: 1007.10, low: 1006.50);
    // Next tick should execute the trailing stop
    broker.tick('BTCUSDT', 1006.50);

    expect(ts.status, OrderStatus.filled);

    // Ensure it triggered only once: exactly one ledger entry for this order id
    final fillsForTs = broker.ledger.where((f) => f.orderId == ts.id).toList();
    expect(fillsForTs.length, 1);
    // Fill should be taker at the post-trigger market tick price
    expect(fillsForTs.first.price, closeTo(1006.50, 1e-9));
  });
}
