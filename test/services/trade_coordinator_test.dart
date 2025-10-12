import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/entities.dart' as ai;
import 'package:mytrademate/services/signal_policy.dart';
import 'package:mytrademate/services/trade_coordinator.dart';
import 'package:mytrademate/services/brokers.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemBroker implements MarketExecution {
  OrderParams? last;
  @override
  Future<String> placeOrder(OrderParams p) async {
    last = p;
    return 'ok';
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maybeTrade respects consent and persists counters', () async {
    Future<ai.Prediction?> fakeFetcher(String s) async => ai.Prediction(
          symbol: s,
          asOf: DateTime.utc(2025, 1, 1),
          pBuy: 0.7,
          pHold: 0.2,
          pSell: 0.1,
          expReturn: 0.003,
          annVol: 0.2,
          relVolume: 1.0,
        );
    final prefs = await TradingPrefs.load();
    await prefs.setUserConsentTrading(true);
    await prefs.setThresholds(buy: 0.55, sell: 0.45);
    await prefs.setMinConfidence(50);
    await prefs.setCooldown(Duration.zero);
    await prefs.setMaxTradesPerDay(5);
    await prefs.setQuotePerTrade(25);

    final broker = _MemBroker();
    final coord = TradeCoordinator(
      fetchPrediction: fakeFetcher,
      policy: SignalPolicy(),
      broker: broker,
      prefs: prefs,
      now: () => DateTime.utc(2024, 1, 1, 0, 0, 0),
    );

    await coord.maybeTrade('BTCUSDT');
    expect(broker.last, isNotNull);
    expect(broker.last!.symbol, 'BTCUSDT');
    expect(broker.last!.side, 'BUY');
    expect(broker.last!.type, 'MARKET');

    final lastAt = await prefs.getLastTradeAt('BTCUSDT');
    expect(lastAt, isNotNull);
    final cnt = await prefs.getTradeCountForDay(DateTime.utc(2024, 1, 1));
    expect(cnt, 1);
  });
}
