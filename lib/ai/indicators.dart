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
  final variance = window.map((x) => pow(x - middle, 2)).reduce((a, b) => a + b) / period;
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

