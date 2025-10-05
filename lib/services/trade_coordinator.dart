import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/signal_policy.dart';
import 'package:mytrademate/services/brokers.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

class TradeCoordinator {
  final AIService ai;
  final SignalPolicy policy;
  final MarketExecution broker;
  final TradingPrefs prefs;
  final DateTime Function() now;

  TradeCoordinator({
    required this.ai,
    required this.policy,
    required this.broker,
    required this.prefs,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<void> maybeTrade(String symbol) async {
    final pred = await ai.getPrediction(symbol);

    // create a policy configured with persisted prefs on-the-fly
    final (buy, sell, hup, hdn) = await prefs.getThresholds();
    final minConf = await prefs.getMinConfidence();
    final cool = await prefs.getCooldown();
    final maxDay = await prefs.getMaxTradesPerDay();
    final consent = await prefs.getUserConsentTrading();
    final quote = await prefs.getQuotePerTrade();

    final pol = SignalPolicy(
      cfg: SignalPolicyConfig(
        buyThreshold: buy,
        sellThreshold: sell,
        hysteresisBand: (hup.abs() + hdn.abs()) / 2.0,
        minConfidence: minConf,
        cooldown: cool,
        maxTradesPerDay: maxDay,
      ),
      now: now,
      userConsent: () => consent,
      quoteSizer: (_) => quote,
    );

    final intent = pol.evaluate(symbol: symbol, probUp: pred.probUp, confidence: pred.confidence);
    if (intent == null) return;

    // place as MARKET using quote sizing by converting to quantity by last target price approximation
    // In a real system, fetch real-time price for symbol here.
    final qty = (intent.quoteAmount / (pred.targetPrice > 0 ? pred.targetPrice : 1.0)).abs();
    await broker.placeOrder(OrderParams(symbol: symbol, side: intent.side, type: 'MARKET', quantity: qty));

    await prefs.setLastTradeAt(symbol, now());
    await prefs.incTradeCountForDay(now());
  }
}


