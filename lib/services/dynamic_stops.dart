class DynamicStops {
  static const Map<String, double> _volMultiplier = {
    '5m': 1.5,
    '15m': 2.0,
    '1h': 2.5,
    '4h': 3.0,
    '1d': 3.5,
  };

  /// Calculates stop-loss based on entry price, annualized volatility (0..1) and timeframe.
  double calculateStopLoss(double entryPrice, double volatility, String timeframe) {
    final m = _volMultiplier[timeframe] ?? 2.0;
    final stop = entryPrice * (1 - (volatility * m));
    return stop.isFinite ? stop : entryPrice;
  }

  /// Helper: absolute stop distance from entry, using volatility and timeframe.
  double calculateStopDistance(double entryPrice, double volatility, String timeframe) {
    final m = _volMultiplier[timeframe] ?? 2.0;
    final dist = entryPrice * (volatility * m);
    return dist.isFinite ? dist : 0.0;
  }

  /// Calculates take-profit using a dynamic risk/reward ratio scaled by confidence.
  /// expectedReturn is a fractional estimate (e.g., 0.01 = +1%).
  double calculateTakeProfit(
    double entryPrice,
    double expectedReturn,
    double confidence, {
    required double volatility,
    String timeframe = '5m',
  }) {
    // Higher confidence → higher target (min 2.0 RR)
    final riskRewardRatio = 2.0 + (confidence / 100.0);
    final stopDistance = calculateStopDistance(entryPrice, volatility, timeframe);
    final tp = entryPrice + (stopDistance * riskRewardRatio);
    return tp.isFinite ? tp : entryPrice * (1.0 + expectedReturn.abs());
  }
}


