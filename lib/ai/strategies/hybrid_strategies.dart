import 'dart:math';
import '../entities.dart';
import '../indicators.dart';

/// Market regime classification based on volatility and trend
enum MarketRegime { bullish, bearish, range, highVol }

class RegimeContext {
  final MarketRegime regime;
  final double volatility; // annualized (0.65 = 65%)
  final double trendStrength; // -1..1 based on EMA slope
  const RegimeContext({
    required this.regime,
    required this.volatility,
    required this.trendStrength,
  });
}

RegimeContext detectMarketRegime(List<Candle> candles) {
  if (candles.length < 64) {
    return const RegimeContext(regime: MarketRegime.range, volatility: 0.3, trendStrength: 0.0);
  }
  final closes = candles.map((c) => c.close).toList();
  final v = ewmaVol(closes, lambda: 0.94).clamp(0.01, 3.0);
  // Trend strength from EMA(12) - EMA(26) normalized by price
  final ema12 = ema(closes, 12);
  final ema26 = ema(closes, 26);
  final last = closes.last;
  final slope = (!ema12.isFinite || !ema26.isFinite || last == 0)
      ? 0.0
      : ((ema12 - ema26) / last).clamp(-0.05, 0.05);
  final ts = slope / 0.05; // normalize to roughly -1..1

  MarketRegime regime;
  if (v > 1.0) {
    regime = MarketRegime.highVol;
  } else if (ts > 0.2) {
    regime = MarketRegime.bullish;
  } else if (ts < -0.2) {
    regime = MarketRegime.bearish;
  } else {
    regime = MarketRegime.range;
  }
  return RegimeContext(regime: regime, volatility: v, trendStrength: ts);
}

/// Dynamic weights based on asset volatility and market regime
/// Returns weights in [0,1] that sum to 1.0 for (scalper, swing, position)
({double scalper, double swing, double position}) calculateDynamicWeights({
  required double volatility,
  required MarketRegime regime,
}) {
  double wS, wW, wP;
  // Base by volatility: higher vol → favor scalper and swing
  if (volatility >= 0.8) {
    wS = 0.5; wW = 0.35; wP = 0.15;
  } else if (volatility >= 0.4) {
    wS = 0.35; wW = 0.40; wP = 0.25;
  } else {
    wS = 0.20; wW = 0.40; wP = 0.40;
  }
  // Regime tilt
  switch (regime) {
    case MarketRegime.bullish:
      wP += 0.10; wW += 0.05; wS -= 0.15; break;
    case MarketRegime.bearish:
      wS += 0.10; wW += 0.05; wP -= 0.15; break;
    case MarketRegime.range:
      wS += 0.05; wW += 0.05; wP -= 0.10; break;
    case MarketRegime.highVol:
      wS += 0.15; wW += 0.05; wP -= 0.20; break;
  }
  // Normalize and clamp
  double sum = max(1e-9, wS + wW + wP);
  wS = (wS / sum).clamp(0.0, 1.0);
  wW = (wW / sum).clamp(0.0, 1.0);
  wP = (wP / sum).clamp(0.0, 1.0);
  return (scalper: wS, swing: wW, position: wP);
}

/// Weighted vote across signals: BUY=+1, SELL=-1, HOLD=0
String weightedVote(Map<String, int> signals, ({double scalper, double swing, double position}) w) {
  double sum = 0.0;
  int sScalper = signals['scalper'] ?? 0;
  int sSwing = signals['swing'] ?? 0;
  int sPosition = signals['position'] ?? 0;
  sum += sScalper * w.scalper;
  sum += sSwing * w.swing;
  sum += sPosition * w.position;
  if (sum > 0.05) return 'BUY';
  if (sum < -0.05) return 'SELL';
  return 'HOLD';
}

double calculateConfidence(Map<String, int> signals) {
  // Confidence: fraction of non-HOLD agreeing plus magnitude weighting
  final values = signals.values.where((v) => v != 0).toList();
  if (values.isEmpty) return 0.4;
  final agree = values.where((v) => v == 1).length;
  final disagree = values.where((v) => v == -1).length;
  final total = values.length;
  final consensus = (agree - disagree).abs() / total;
  return (0.5 + 0.5 * consensus).clamp(0.0, 1.0);
}

double riskAdjustedSize(double volatility, String finalSignal) {
  if (finalSignal == 'HOLD') return 0.0;
  // Size inversely proportional to volatility, capped
  final inv = (1.0 / max(0.15, volatility)).clamp(0.2, 5.0);
  final base = (inv / 10.0).clamp(0.01, 0.05); // 1%-5%
  return base;
}

/// Helper: get closes list
List<double> _closes(List<Candle> x) => x.map((c) => c.close).toList();

// --- Hybrid Strategies ---

/// Strategy 1: Scalper (5m) + Swing (4h) + Position (1d)
Map<String, dynamic> hybridStrategy1({
  required List<Candle> tf5m,
  required List<Candle> tf4h,
  required List<Candle> tf1d,
}) {
  final scalper = emaCrossoverSignal(_closes(tf5m), 8, 21);
  final swing = rsiMomentumSignal(_closes(tf4h), period: 14, overbought: 70, oversold: 30);
  final pos = ichimokuCloudSignal(tf1d);
  final regime = detectMarketRegime(tf4h);
  final w = calculateDynamicWeights(volatility: regime.volatility, regime: regime.regime);
  final action = weightedVote({'scalper': scalper, 'swing': swing, 'position': pos}, w);
  return {
    'action': action,
    'confidence': calculateConfidence({'scalper': scalper, 'swing': swing, 'position': pos}),
    'position_size': riskAdjustedSize(regime.volatility, action),
  };
}

/// Strategy 2: Mean-reversion scalper + MACD swing + Cloud filter
Map<String, dynamic> hybridStrategy2({
  required List<Candle> tf5m,
  required List<Candle> tf1h,
  required List<Candle> tf1d,
}) {
  // Regime-aware parameter tuning
  final regime = detectMarketRegime(tf1d);
  final highVol = regime.volatility >= 0.8 || regime.regime == MarketRegime.highVol;
  final bandPeriod = highVol ? 14 : 20;
  final bandMult = highVol ? 2.5 : 2.0;
  final adxPeriod = highVol ? 10 : 14;
  final adxTrendThresh = highVol ? 28.0 : 25.0;

  // Mean reversion on 5m via Bollinger
  final closes5 = _closes(tf5m);
  final bb5 = bollingerBands(closes5, period: bandPeriod, stdDevMultiplier: bandMult);
  int scalper = 0;
  final last5 = closes5.last;
  if (last5 < bb5.lower) scalper = 1; else if (last5 > bb5.upper) scalper = -1;

  // Trend following on 1h via ADX and EMA(12/26)
  final closes1h = _closes(tf1h);
  final adxVal = adx(tf1h, period: adxPeriod);
  final emaSignal = emaCrossoverSignal(closes1h, 12, 26);
  int swing = 0;
  if (adxVal >= adxTrendThresh) {
    swing = emaSignal; // use trend direction only when ADX strong
  } else {
    swing = 0; // weak trend → let scalper dominate
  }

  // Position bias by Ichimoku on daily
  final pos = ichimokuCloudSignal(tf1d);
  final w = calculateDynamicWeights(volatility: regime.volatility, regime: regime.regime);
  final action = weightedVote({'scalper': scalper, 'swing': swing, 'position': pos}, w);
  return {
    'action': action,
    'confidence': calculateConfidence({'scalper': scalper, 'swing': swing, 'position': pos}),
    'position_size': riskAdjustedSize(regime.volatility, action),
    'debug': {
      'bbPeriod': bandPeriod,
      'bbMult': bandMult,
      'adx': adxVal,
      'adxThresh': adxTrendThresh,
    }
  };
}

/// Strategy 3: Trend-following across TF with RSI gating
Map<String, dynamic> hybridStrategy3({
  required List<Candle> tf15m,
  required List<Candle> tf4h,
  required List<Candle> tf1d,
}) {
  final s15 = emaCrossoverSignal(_closes(tf15m), 12, 26);
  final s4h = emaCrossoverSignal(_closes(tf4h), 20, 50);
  final rsiD = rsiMomentumSignal(_closes(tf1d), period: 14, overbought: 65, oversold: 35);
  final regime = detectMarketRegime(tf4h);
  final w = calculateDynamicWeights(volatility: regime.volatility, regime: regime.regime);
  final action = weightedVote({'scalper': s15, 'swing': s4h, 'position': rsiD}, w);
  return {
    'action': action,
    'confidence': calculateConfidence({'scalper': s15, 'swing': s4h, 'position': rsiD}),
    'position_size': riskAdjustedSize(regime.volatility, action),
  };
}

/// Strategy 4: Breakout on 1h confirmed by daily trend, 5m timing
Map<String, dynamic> hybridStrategy4({
  required List<Candle> tf5m,
  required List<Candle> tf1h,
  required List<Candle> tf1d,
}) {
  final closes1h = _closes(tf1h);
  final sma20h = sma(closes1h, 20);
  final last1h = closes1h.last;
  int swing = 0;
  if (sma20h.isFinite) {
    if (last1h > sma20h) swing = 1; else if (last1h < sma20h) swing = -1;
  }
  final pos = emaCrossoverSignal(_closes(tf1d), 50, 200);
  final scalper = emaCrossoverSignal(_closes(tf5m), 5, 13);
  final regime = detectMarketRegime(tf1d);
  final w = calculateDynamicWeights(volatility: regime.volatility, regime: regime.regime);
  final action = weightedVote({'scalper': scalper, 'swing': swing, 'position': pos}, w);
  return {
    'action': action,
    'confidence': calculateConfidence({'scalper': scalper, 'swing': swing, 'position': pos}),
    'position_size': riskAdjustedSize(regime.volatility, action),
  };
}

/// Strategy 5: Volatility-adaptive position sizing with cloud bias
Map<String, dynamic> hybridStrategy5({
  required List<Candle> tf5m,
  required List<Candle> tf4h,
  required List<Candle> tf1d,
}) {
  int scalper = emaCrossoverSignal(_closes(tf5m), 10, 30);
  int swing = rsiMomentumSignal(_closes(tf4h), period: 21, overbought: 68, oversold: 32);
  int position = ichimokuCloudSignal(tf1d);
  final regime = detectMarketRegime(tf4h);
  final w = calculateDynamicWeights(volatility: regime.volatility, regime: regime.regime);
  final action = weightedVote({'scalper': scalper, 'swing': swing, 'position': position}, w);
  return {
    'action': action,
    'confidence': calculateConfidence({'scalper': scalper, 'swing': swing, 'position': position}),
    'position_size': riskAdjustedSize(regime.volatility, action),
  };
}


