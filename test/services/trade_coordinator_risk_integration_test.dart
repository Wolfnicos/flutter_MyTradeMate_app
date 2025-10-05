import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/brokers.dart';
import 'package:mytrademate/services/risk_manager.dart';
import 'package:mytrademate/services/signal_policy.dart';
import 'package:mytrademate/services/trade_coordinator.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BrokerMock implements MarketExecution {
  int calls = 0;
  @override
  Future<String> placeOrder(OrderParams p) async {
    calls++;
    return 'ok';
  }
}

Future<TradingPrefs> _makePrefs() async {
  SharedPreferences.setMockInitialValues({});
  return TradingPrefs.inMemoryForTest();
}

void main() {
  test('RiskManager violation blocks order placement', () async {
    final ai = AIService(enableFake: true);
    final pol = SignalPolicy(cfg: const SignalPolicyConfig(), now: DateTime.now, userConsent: () => true, quoteSizer: (_) => 100.0);
    final broker = _BrokerMock();
    final prefs = await _makePrefs();
    final risk = RiskManager(const RiskConfig(maxPositionQuoteUsdt: 50.0)); // will block 100 quote
    final tc = TradeCoordinator(ai: ai, policy: pol, broker: broker, prefs: prefs, risk: risk, now: () => DateTime.fromMillisecondsSinceEpoch(0));

    expect(() => tc.maybeTrade('BTCUSDT'), throwsA(isA<RiskViolation>()));
    expect(broker.calls, 0);
  });
}


