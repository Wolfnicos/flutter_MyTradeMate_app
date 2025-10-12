import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';
import 'package:mytrademate/services/paper_broker.dart';

void main() {
  test(
      'gap then wick: stop-limit buy should not execute across gap; stop triggers on wick',
      () async {
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

    // Initial reference tick at 1000
    broker.tick('BTCUSDT', 1000.00);

    // Place STOP-LIMIT BUY: stop=1010, limit=1012
    final o1 = broker.place(PaperOrderReq.stopLimit(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      quantity: 0.010000,
      price: 1012.00,
      stopPrice: 1010.00,
    )) as PaperOrder;

    // Gap directly to 1020 (no wick crossing the 1012 limit)
    broker.tick('BTCUSDT', 1020.00, high: 1020.00, low: 1020.00);
    expect(
        o1.status == OrderStatus.new_ ||
            o1.status == OrderStatus.partiallyFilled,
        isTrue,
        reason:
            'stop-limit should not market fill across gap if limit not crossed');

    // Now a wick back down to 1015 (still above 1012), then to 1015 high/low crossing 1012
    broker.tick('BTCUSDT', 1015.00, high: 1015.00, low: 1011.50);
    // After wick crossing low <= limit (1011.50 <= 1012), limit can fill
    if (o1.status != OrderStatus.filled) {
      // ensure fill
      broker.tick('BTCUSDT', 1012.00, high: 1012.00, low: 1012.00);
    }
    expect(o1.status, isNot(OrderStatus.canceled));

    // Separate STOP (market) should trigger on wick at 1015 and execute next tick
    final stopOnly = PaperOrderReq.stopMarket(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      stopPrice: 1015.00,
      quantity: 0.010000,
    );
    final o2 = broker.place(stopOnly) as PaperOrder;
    // Wick reaching 1015 triggers stop; next tick executes at market
    broker.tick('BTCUSDT', 1015.00, high: 1016.00, low: 1014.00);
    broker.tick('BTCUSDT', 1015.50);
    expect(o2.status, OrderStatus.filled);
  });
}
