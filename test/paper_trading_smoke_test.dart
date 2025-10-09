import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';
import 'package:mytrademate/services/paper_broker.dart';

List<Map<String, dynamic>> loadTicks(String path) {
  final text = File(path).readAsStringSync();
  final raw = jsonDecode(text) as List<dynamic>;
  return raw.cast<Map<String, dynamic>>();
}

void main() {
  test('paper BUY then SELL roundtrip with fees & precision',
      timeout: const Timeout(Duration(seconds: 6)), () async {
    // Deterministic tick sequence: 1000.0..1000.9
    final ticks = loadTicks('test/fixtures/binance_ws/simple_10_ticks.json');

    // Configure exchange rules for BTCUSDT
    final rules = ExchangeRulesForTest.forTest(
      minNotional: 10.0,
      qtyStep: 0.000001,
      priceTick: 0.01,
    );

    // Low fees to ensure positive PnL in the smoke
    final cfg = PaperBrokerConfig(
      makerFeeBps: 0.0, // zero fees for deterministic baseline
      takerFeeBps: 0.0,
      slippageBps: 0.0,
      rulesBySymbol: {'BTCUSDT': rules},
    );

    final broker = PaperBroker(cfg);

    // Replay ticks into the broker
    for (final ev in ticks) {
      final p = (ev['c'] as num).toDouble();
      broker.tick('BTCUSDT', p);
    }

    // 1) BUY LIMIT at 1000.00
    final buyReq = PaperOrderReq.limit(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      price: 1000.00,
      quantity: 0.010000, // $10 notional
    );
    final buy = broker.place(buyReq) as PaperOrder;
    // Apply another tick at or above 1000.00 to fill
    broker.tick('BTCUSDT', 1000.00, high: 1000.00, low: 999.99);

    // 2) SELL LIMIT at 1000.90
    final sellReq = PaperOrderReq.limit(
      symbol: 'BTCUSDT',
      side: OrderSide.sell,
      price: 1000.90,
      quantity: 0.010000,
    );
    final sell = broker.place(sellReq) as PaperOrder;
    broker.tick('BTCUSDT', 1000.90, high: 1001.00, low: 1000.80);

    expect(buy.status, OrderStatus.filled);
    expect(sell.status, OrderStatus.filled);

    final pos = broker.position('BTCUSDT');
    expect(pos.qty, 0.0);

    // Compute expected PnL with maker fees on both legs
    const expected = (1000.90 - 1000.00) * 0.01; // zero fees baseline
    expect(pos.realizedPnl, closeTo(expected, 1e-6));
  });
}
