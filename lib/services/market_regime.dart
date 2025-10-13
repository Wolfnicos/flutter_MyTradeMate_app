import 'dart:math' as math;
import 'package:mytrademate/ai/entities.dart';

enum RegimeType { highVolatility, sideways, trendingUp, trendingDown }

class StrategyAdjustments {
  final double positionSizeMultiplier; // < 1.0 reduces size, > 1.0 increases
  final double stopLossMultiplier; // > 1.0 widens stops, < 1.0 tightens
  final double holdBias; // 0..1: probability weight to HOLD when ambiguous
  final bool tightenStops;

  const StrategyAdjustments({
    this.positionSizeMultiplier = 1.0,
    this.stopLossMultiplier = 1.0,
    this.holdBias = 0.0,
    this.tightenStops = false,
  });
}

class MarketRegime {
  /// Detects market regime using simple volatility and trend estimators
  RegimeType detectRegime(List<Candle> candles) {
    if (candles.length < 20) return RegimeType.sideways;
    final vol = _calculateVolatility(candles);
    final trend = _calculateTrend(candles);

    if (vol > 0.30) return RegimeType.highVolatility;
    if (trend.abs() < 0.10) return RegimeType.sideways;
    return trend > 0 ? RegimeType.trendingUp : RegimeType.trendingDown;
  }

  /// Returns recommended strategy adjustments for the detected regime
  StrategyAdjustments adjustStrategy(RegimeType regime) {
    switch (regime) {
      case RegimeType.highVolatility:
        // Reduce size and widen stops in high vol
        return const StrategyAdjustments(
          positionSizeMultiplier: 0.5,
          stopLossMultiplier: 1.5,
          holdBias: 0.1,
          tightenStops: false,
        );
      case RegimeType.sideways:
        // Favor HOLD and tighter stops
        return const StrategyAdjustments(
          positionSizeMultiplier: 0.8,
          stopLossMultiplier: 0.8,
          holdBias: 0.25,
          tightenStops: true,
        );
      case RegimeType.trendingUp:
        return const StrategyAdjustments(
          positionSizeMultiplier: 1.0,
          stopLossMultiplier: 1.0,
          holdBias: 0.0,
          tightenStops: false,
        );
      case RegimeType.trendingDown:
        // Smaller size, slightly tighter stops
        return const StrategyAdjustments(
          positionSizeMultiplier: 0.7,
          stopLossMultiplier: 0.9,
          holdBias: 0.15,
          tightenStops: true,
        );
    }
  }

  // --- Helpers ---

  /// Annualized volatility (rough), using simple returns
  double _calculateVolatility(List<Candle> candles) {
    final closes = candles.map((c) => c.close).toList();
    if (closes.length < 2) return 0.0;
    final rets = <double>[];
    for (int i = 1; i < closes.length; i++) {
      final prev = closes[i - 1];
      final curr = closes[i];
      rets.add(prev == 0 ? 0.0 : (curr / prev - 1.0));
    }
    if (rets.isEmpty) return 0.0;
    final mean = rets.reduce((a, b) => a + b) / rets.length;
    double variance = 0.0;
    for (final r in rets) {
      variance += (r - mean) * (r - mean);
    }
    variance /= rets.length;
    final std = math.sqrt(variance);
    // Approx annualization factor (5m bars → ~ 365 * 288 per year)
    return (std * math.sqrt(365.0)).clamp(0.0, 2.0);
  }

  /// Trend slope normalized by average price (percent per step)
  double _calculateTrend(List<Candle> candles) {
    final n = candles.length;
    final y = candles.map((c) => c.close).toList();
    final x = List<double>.generate(n, (i) => i.toDouble());
    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;
    double num = 0.0, den = 0.0;
    for (int i = 0; i < n; i++) {
      final dx = x[i] - xMean;
      num += dx * (y[i] - yMean);
      den += dx * dx;
    }
    final slope = den == 0 ? 0.0 : num / den;
    final trendPctPerStep = yMean == 0 ? 0.0 : (slope / yMean);
    return (trendPctPerStep * 100.0).clamp(-100.0, 100.0);
  }
}


