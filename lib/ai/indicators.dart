import 'dart:math';
import 'entities.dart';

/// EMA - Exponential Moving Average
double ema(List<double> values, int period) {
  if (values.isEmpty || values.length < period) return double.nan;

  final k = 2.0 / (period + 1);

  // Initialize with SMA
  var emaValue = values.take(period).reduce((a, b) => a + b) / period;

  // Apply EMA formula
  for (final v in values.skip(period)) {
    emaValue = v * k + emaValue * (1 - k);
  }

  return emaValue;
}

/// SMA - Simple Moving Average
double sma(List<double> values, int period) {
  if (values.isEmpty || values.length < period) return double.nan;
  final window = values.sublist(values.length - period);
  return window.reduce((a, b) => a + b) / period;
}

/// RSI - Relative Strength Index
double rsi(List<double> closes, {int period = 14}) {
  if (closes.length <= period) return double.nan;

  double gain = 0.0;
  double loss = 0.0;

  // Calculate initial average gain/loss
  for (int i = 1; i <= period; i++) {
    final diff = closes[i] - closes[i - 1];
    if (diff >= 0) {
      gain += diff;
    } else {
      loss -= diff; // Absolute value
    }
  }

  double avgGain = gain / period;
  double avgLoss = loss / period;

  // Wilder's smoothing for remaining values
  for (int i = period + 1; i < closes.length; i++) {
    final diff = closes[i] - closes[i - 1];
    final currentGain = max(0.0, diff);
    final currentLoss = max(0.0, -diff);

    avgGain = (avgGain * (period - 1) + currentGain) / period;
    avgLoss = (avgLoss * (period - 1) + currentLoss) / period;
  }

  if (avgLoss == 0) return 100.0;

  final rs = avgGain / avgLoss;
  return 100.0 - (100.0 / (1.0 + rs));
}

/// MACD - Moving Average Convergence Divergence
({double macd, double signal, double histogram}) macdValues(
  List<double> closes, {
  int fastPeriod = 12,
  int slowPeriod = 26,
  int signalPeriod = 9,
}) {
  if (closes.length < slowPeriod + signalPeriod) {
    return (macd: double.nan, signal: double.nan, histogram: double.nan);
  }

  final emaFast = ema(closes, fastPeriod);
  final emaSlow = ema(closes, slowPeriod);
  final macdLine = emaFast - emaSlow;

  // Calculate signal line (EMA of MACD)
  // For simplicity, use last value - in production, calculate full MACD history
  final signalLine = macdLine; // Simplified
  final histogram = macdLine - signalLine;

  return (macd: macdLine, signal: signalLine, histogram: histogram);
}

/// ATR - Average True Range (volatilitate)
double atr(List<Candle> candles, {int period = 14}) {
  if (candles.length < period + 1) return double.nan;

  final trueRanges = <double>[];
  for (int i = 1; i < candles.length; i++) {
    trueRanges.add(candles[i].trueRange(candles[i - 1]));
  }

  if (trueRanges.isEmpty) return double.nan;

  return sma(trueRanges, min(period, trueRanges.length));
}

/// OBV - On-Balance Volume
double obv(List<Candle> candles) {
  if (candles.length < 2) return 0.0;

  double obvValue = 0.0;
  for (int i = 1; i < candles.length; i++) {
    if (candles[i].close > candles[i - 1].close) {
      obvValue += candles[i].volume;
    } else if (candles[i].close < candles[i - 1].close) {
      obvValue -= candles[i].volume;
    }
    // Equal close = no change
  }

  return obvValue;
}

/// EWMA Volatility - Exponentially Weighted Moving Average Volatility
/// Formula: σ_t = sqrt((1-λ)∑λ^(i-1) * r_(t-i)^2)
double ewmaVol(List<double> closes, {double lambda = 0.94}) {
  if (closes.length < 2) return double.nan;

  double variance = 0.0;

  for (int i = 1; i < closes.length; i++) {
    final logReturn = log(closes[i] / closes[i - 1]);
    final weight = pow(lambda, closes.length - 1 - i).toDouble();
    variance += (1 - lambda) * weight * logReturn * logReturn;
  }

  final dailyVol = sqrt(variance);

  // Anualizează pentru crypto (365 zile trading)
  return dailyVol * sqrt(365);
}

/// Relative Volume - raport față de SMA
double relativeVolume(List<Candle> candles, {int period = 20}) {
  if (candles.length < period) return 1.0;

  final volumes = candles.map((c) => c.volume).toList();
  final avgVolume = sma(volumes, period);

  if (avgVolume.isNaN || avgVolume == 0) return 1.0;

  return candles.last.volume / avgVolume;
}

/// Bollinger Bands
({double upper, double middle, double lower}) bollingerBands(
  List<double> closes, {
  int period = 20,
  double stdDevMultiplier = 2.0,
}) {
  if (closes.length < period) {
    return (upper: double.nan, middle: double.nan, lower: double.nan);
  }

  final middle = sma(closes, period);

  // Calculate standard deviation
  final window = closes.sublist(closes.length - period);
  final variance =
      window.map((x) => pow(x - middle, 2)).reduce((a, b) => a + b) / period;
  final stdDev = sqrt(variance);

  return (
    upper: middle + stdDev * stdDevMultiplier,
    middle: middle,
    lower: middle - stdDev * stdDevMultiplier,
  );
}

/// Calculate all indicators pentru o fereastră
Indicators calculateIndicators(List<Candle> candles) {
  final closes = candles.map((c) => c.close).toList();
  final macdData = macdValues(closes);

  return Indicators(
    rsi14: rsi(closes, period: 14),
    ema12: ema(closes, 12),
    ema26: ema(closes, 26),
    macd: macdData.macd,
    atr14: atr(candles, period: 14),
    obv: obv(candles),
    ewmaVol: ewmaVol(closes, lambda: 0.94),
    relVolume: relativeVolume(candles, period: 20),
  );
}

/// Ichimoku Cloud components (simplified, computed for the last candle)
/// Returns current Tenkan-sen (conversion), Kijun-sen (base),
/// Senkou Span A/B (cloud edges), and Chikou Span (lagging close)
({
  double tenkan,
  double kijun,
  double spanA,
  double spanB,
  double chikou,
}) ichimokuCloud(
  List<Candle> candles, {
  int tenkanPeriod = 9,
  int kijunPeriod = 26,
  int senkouBPeriod = 52,
  int chikouLag = 26,
}) {
  if (candles.length < senkouBPeriod + 1) {
    return (
      tenkan: double.nan,
      kijun: double.nan,
      spanA: double.nan,
      spanB: double.nan,
      chikou: double.nan,
    );
  }

  double midHighLow(int period, int endIdx) {
    final start = (endIdx - period + 1).clamp(0, endIdx);
    double highest = candles[start].high;
    double lowest = candles[start].low;
    for (int i = start + 1; i <= endIdx; i++) {
      if (candles[i].high > highest) highest = candles[i].high;
      if (candles[i].low < lowest) lowest = candles[i].low;
    }
    return (highest + lowest) / 2.0;
  }

  final lastIdx = candles.length - 1;
  final tenkan = midHighLow(tenkanPeriod, lastIdx);
  final kijun = midHighLow(kijunPeriod, lastIdx);
  final spanA =
      (tenkan + kijun) / 2.0; // forward-shift ignored in simplified calc
  final spanB = midHighLow(senkouBPeriod, lastIdx);

  // Chikou span: close price shifted back by chikouLag (simplified: value only)
  final chikouIdx = (lastIdx - chikouLag).clamp(0, lastIdx);
  final chikou = candles[chikouIdx].close;

  return (
    tenkan: tenkan,
    kijun: kijun,
    spanA: spanA,
    spanB: spanB,
    chikou: chikou
  );
}

/// Determine if price is above the Ichimoku cloud (bullish), below (bearish), or inside (neutral)
/// Returns 1 for bullish, -1 for bearish, 0 for inside/undefined
int ichimokuCloudSignal(List<Candle> candles) {
  final cloud = ichimokuCloud(candles);
  if ([cloud.tenkan, cloud.kijun, cloud.spanA, cloud.spanB, cloud.chikou]
      .any((x) => !x.isFinite)) {
    return 0;
  }
  final lastClose = candles.last.close;
  final upper = cloud.spanA > cloud.spanB ? cloud.spanA : cloud.spanB;
  final lower = cloud.spanA > cloud.spanB ? cloud.spanB : cloud.spanA;
  if (lastClose > upper) return 1;
  if (lastClose < lower) return -1;
  return 0;
}

/// EMA crossover signal: 1 if fastEMA > slowEMA, -1 if fastEMA < slowEMA, 0 if undefined
int emaCrossoverSignal(List<double> closes, int fastPeriod, int slowPeriod) {
  if (closes.length < slowPeriod) return 0;
  final fast = ema(closes, fastPeriod);
  final slow = ema(closes, slowPeriod);
  if (!fast.isFinite || !slow.isFinite) return 0;
  if (fast > slow) return 1;
  if (fast < slow) return -1;
  return 0;
}

/// RSI momentum signal using overbought/oversold thresholds:
/// 1 for bullish (RSI > overbought), -1 for bearish (RSI < oversold), else 0
int rsiMomentumSignal(List<double> closes,
    {int period = 14, double overbought = 70, double oversold = 30}) {
  if (closes.length <= period) return 0;
  final rr = rsi(closes, period: period);
  if (!rr.isFinite) return 0;
  if (rr >= overbought) return 1;
  if (rr <= oversold) return -1;
  return 0;
}

/// ADX (Average Directional Movement Index) proxy at the last bar
/// Returns a simplified ADX value using sums over the last [period] bars
double adx(List<Candle> candles, {int period = 14}) {
  if (candles.length < period + 1) return 0.0;
  double trSum = 0.0, plusDmSum = 0.0, minusDmSum = 0.0;
  for (int i = candles.length - period; i < candles.length; i++) {
    if (i == 0) continue;
    final high = candles[i].high;
    final low = candles[i].low;
    final prevClose = candles[i - 1].close;
    final prevHigh = candles[i - 1].high;
    final prevLow = candles[i - 1].low;
    final tr = [
      high - low,
      (high - prevClose).abs(),
      (low - prevClose).abs(),
    ].reduce((a, b) => a > b ? a : b);
    final upMove = high - prevHigh;
    final downMove = prevLow - low;
    final plusDm = (upMove > downMove && upMove > 0) ? upMove : 0.0;
    final minusDm = (downMove > upMove && downMove > 0) ? downMove : 0.0;
    trSum += tr;
    plusDmSum += plusDm;
    minusDmSum += minusDm;
  }
  if (trSum == 0) return 0.0;
  final plusDi = 100.0 * (plusDmSum / trSum);
  final minusDi = 100.0 * (minusDmSum / trSum);
  final den = (plusDi + minusDi).abs() < 1e-12 ? 1e-12 : (plusDi + minusDi);
  final dx = 100.0 * ((plusDi - minusDi).abs() / den);
  return dx; // ADX proxy
}
