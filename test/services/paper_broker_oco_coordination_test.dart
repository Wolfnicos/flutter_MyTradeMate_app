import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';
import 'package:mytrademate/services/paper_broker.dart';

void main() {
  test('OCO: when TP fills, SL cancels',
      timeout: const Timeout(Duration(seconds: 5)), () async {
    // Exchange rules for precision and MIN_NOTIONAL
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 10.0,
      qtyStep: 0.000001,
      priceTick: 0.01,
    );
    final cfg = PaperBrokerConfig(
      makerFeeBps: 0.5, // 0.005%
      takerFeeBps: 1.0, // 0.01%
      rulesBySymbol: {'BTCUSDT': rules},
    );
    final broker = PaperBroker(cfg);

    // Start around 1000
    broker.tick('BTCUSDT', 1000.00);

    // Place an OCO sell: TP limit at 1012, SL stop at 995 with stop-limit 994.5
    final placed = broker.place(PaperOrderReq.ocoSell(
      symbol: 'BTCUSDT',
      quantity: 0.020000,
      limitPrice: 1012.00,
      stopPrice: 995.00,
    )) as PlacedOco;

    // Move price upward to hit take-profit limit first
    broker.tick('BTCUSDT', 1012.00, high: 1012.00, low: 1011.00);

    // The limit leg should have filled; the stop leg should be gone
    final snap = broker.snapshot('BTCUSDT');
    expect(snap.orderById.containsKey(placed.limitId), isFalse,
        reason: 'limit leg should be removed after fill');
    expect(snap.orderById.containsKey(placed.stopId), isFalse,
        reason: 'stop leg should be canceled when TP fills');

    // Exactly one fill event for the TP at ~1012
    final fills = broker.ledger.where((f) => f.symbol == 'BTCUSDT').toList();
    expect(fills.length, 1);
    expect(fills.first.price, closeTo(1012.00, 1e-9));
  });
}
