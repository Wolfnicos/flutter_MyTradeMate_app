import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('Paper trading BUY/SELL roundtrip with PnL', () {
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 10.0,
      qtyStep: 0.001,
      priceTick: 0.01,
    );
    final broker = PaperBroker(
      rules,
      now: () => DateTime.fromMillisecondsSinceEpoch(0),
      cfg: const PaperBrokerConfig(
        makerFeeBps: 10.0, // 0.10%
        takerFeeBps: 10.0, // 0.10%
        slippageBps: 0.0,
      ),
    );

    // initial tick
    broker.tick('BTCUSDT', 100.0);

    // place BUY MARKET
    final buy = broker.place(
      PaperOrderReq.market(symbol: 'BTCUSDT', side: OrderSide.buy, quantity: 0.1),
    ) as PaperOrder;
    expect(buy.status, equals(OrderStatus.filled));

    // price up
    broker.tick('BTCUSDT', 110.0);
    expect(broker.unrealizedPnl('BTCUSDT', 110.0) > 0, isTrue);

    // place SELL MARKET
    final sell = broker.place(
      PaperOrderReq.market(symbol: 'BTCUSDT', side: OrderSide.sell, quantity: 0.1),
    ) as PaperOrder;
    expect(sell.status, equals(OrderStatus.filled));

    // realized PnL positive (quote = USDT)
    expect(broker.realizedPnlUsdt('USDT') > 0, isTrue);
  });
}


