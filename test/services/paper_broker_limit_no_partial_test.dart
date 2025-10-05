import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('LIMIT allowPartial=false umple integral doar la preț', () async {
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 1,
      qtyStep: 1,
      priceTick: 1,
    );

    final broker = PaperBroker(
      rules,
      now: () => DateTime.fromMillisecondsSinceEpoch(0),
      cfg: const PaperBrokerConfig(),
    );

    // pornește sub prețul limit
    broker.tick('AAAUSDT', 95, high: 95, low: 95);

    final order = broker.place(
      PaperOrderReq.limit(
        symbol: 'AAAUSDT',
        side: OrderSide.sell,
        price: 100,
        quantity: 10,
        allowPartial: false,
      ),
    ) as PaperOrder;

    // sub preț → rămâne NEW
    for (final p in [96, 97, 98, 99]) {
      broker.tick('AAAUSDT', p.toDouble(), high: p.toDouble(), low: p.toDouble());
    }
    final st1 = broker.snapshot('AAAUSDT').orderById[order.id]!;
    expect(st1.status, OrderStatus.new_);
    expect(st1.qtyFilled, 0);

    // atinge 100 → execută integral; ordinul dispare din map (filled & closed)
    broker.tick('AAAUSDT', 100, high: 100, low: 100);
    expect(broker.orders.containsKey(order.id), isFalse);
    // Confirmă execuția integrală via ledger
    final last = broker.ledger.last;
    expect(last.orderId, order.id);
    expect(last.symbol, 'AAAUSDT');
    expect(last.qty, 10);
  });
}


