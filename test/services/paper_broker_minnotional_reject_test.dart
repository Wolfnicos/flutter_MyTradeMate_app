import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('LIMIT sub MIN_NOTIONAL este respins', () async {
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 10.0,
      qtyStep: 0.001,
      priceTick: 0.01,
    );

    final broker = PaperBroker(
      rules,
      now: () => DateTime.fromMillisecondsSinceEpoch(0),
      cfg: const PaperBrokerConfig(),
    );

    // 0.5 * 10 = 5 < 10 → reject
    expect(
      () => broker.place(
        PaperOrderReq.limit(
          symbol: 'BTCUSDT',
          side: OrderSide.buy,
          price: 10,
          quantity: 0.5,
        ),
      ),
      throwsA(isA<PaperOrderReject>().having(
        (e) => e.message,
        'message',
        contains('min notional'),
      )),
    );
  });
}
