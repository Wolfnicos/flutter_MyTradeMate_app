import 'dart:collection';

typedef NowFn = DateTime Function();

class SignalPolicyConfig {
  final double buyThreshold; // e.g. 0.55
  final double sellThreshold; // e.g. 0.45
  final double hysteresisBand; // additional margin to flip states
  final double minConfidence; // 0..100
  final Duration cooldown; // time between executed orders per symbol
  final int maxTradesPerDay; // per symbol

  const SignalPolicyConfig({
    this.buyThreshold = 0.55,
    this.sellThreshold = 0.45,
    this.hysteresisBand = 0.02,
    this.minConfidence = 0.0,
    this.cooldown = const Duration(minutes: 5),
    this.maxTradesPerDay = 5,
  });
}

enum LastDecision { none, buy, sell, hold }

class OrderIntent {
  final String symbol;
  final String side; // 'BUY' | 'SELL'
  final double quoteAmount; // USDT to spend/receive target
  const OrderIntent(
      {required this.symbol, required this.side, required this.quoteAmount});
}

class _PerSymbolState {
  LastDecision lastDecision = LastDecision.none;
  DateTime? lastTradeAt;
  int tradesToday = 0;
  DateTime? dayStamp; // yyyy-mm-dd boundary for tradesToday
}

class SignalPolicy {
  final SignalPolicyConfig cfg;
  final NowFn now;
  final double Function(String symbol)
      quoteSizer; // returns quote amount to use
  final bool Function() userConsent; // true if auto-trade is allowed

  final Map<String, _PerSymbolState> _state =
      HashMap<String, _PerSymbolState>();

  SignalPolicy({
    SignalPolicyConfig cfg = const SignalPolicyConfig(),
    NowFn? now,
    double Function(String symbol)? quoteSizer,
    bool Function()? userConsent,
  })  : cfg = cfg,
        now = now ?? DateTime.now,
        quoteSizer = quoteSizer ?? ((_) => 50.0),
        userConsent = userConsent ?? (() => false);

  _PerSymbolState _for(String s) =>
      _state.putIfAbsent(s, () => _PerSymbolState());

  OrderIntent? evaluate({
    required String symbol,
    required double probUp,
    required double confidence,
  }) {
    if (!userConsent()) return null; // explicit consent required
    if (confidence < cfg.minConfidence) return null;

    final st = _for(symbol);
    final tNow = now();
    // reset daily counter
    final todayKey = DateTime(tNow.year, tNow.month, tNow.day);
    if (st.dayStamp == null || _dayChanged(st.dayStamp!, todayKey)) {
      st.dayStamp = todayKey;
      st.tradesToday = 0;
    }
    if (st.tradesToday >= cfg.maxTradesPerDay) return null;
    if (st.lastTradeAt != null &&
        tNow.difference(st.lastTradeAt!) < cfg.cooldown) {
      return null;
    }

    // Hysteresis logic
    final wantBuy = probUp >= cfg.buyThreshold;
    final wantSell = probUp <= cfg.sellThreshold;
    final last = st.lastDecision;
    bool allowBuy = wantBuy;
    bool allowSell = wantSell;
    if (last == LastDecision.buy && wantSell) {
      allowSell = probUp <= (cfg.sellThreshold - cfg.hysteresisBand);
    }
    if (last == LastDecision.sell && wantBuy) {
      allowBuy = probUp >= (cfg.buyThreshold + cfg.hysteresisBand);
    }

    if (allowBuy) {
      final q = quoteSizer(symbol);
      st.lastDecision = LastDecision.buy;
      st.lastTradeAt = tNow;
      st.tradesToday += 1;
      return OrderIntent(symbol: symbol, side: 'BUY', quoteAmount: q);
    }
    if (allowSell) {
      final q = quoteSizer(symbol);
      st.lastDecision = LastDecision.sell;
      st.lastTradeAt = tNow;
      st.tradesToday += 1;
      return OrderIntent(symbol: symbol, side: 'SELL', quoteAmount: q);
    }
    st.lastDecision = LastDecision.hold;
    return null;
  }

  bool _dayChanged(DateTime a, DateTime b) =>
      a.year != b.year || a.month != b.month || a.day != b.day;

  void resetForTest() => _state.clear();
}
