import 'dart:math' as math;

/// Utility for calculating common backtest metrics from equity series.
class MetricsCalculator {
  /// Returns maximum drawdown as a fraction (0.25 = 25%).
  static double maxDrawdown(List<double> equity) {
    if (equity.isEmpty) return 0.0;
    double peak = equity.first;
    double maxDd = 0.0;
    for (final v in equity) {
      if (v > peak) peak = v;
      final dd = (peak - v) / peak;
      if (dd > maxDd) maxDd = dd;
    }
    return maxDd.clamp(0.0, 1.0);
  }

  /// Daily Sharpe ratio from equity history.
  /// Assumes equity points are at regular intervals (e.g., 1 day or resampled).
  static double sharpe(List<double> equity) {
    if (equity.length < 2) return 0.0;
    final rets = <double>[];
    for (int i = 1; i < equity.length; i++) {
      final prev = equity[i - 1];
      if (prev == 0) continue;
      rets.add((equity[i] - prev) / prev);
    }
    if (rets.isEmpty) return 0.0;
    final mean = rets.reduce((a, b) => a + b) / rets.length;
    final varr = rets.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / rets.length;
    final std = varr <= 0 ? 0.0 : math.sqrt(varr);
    if (std == 0.0) return 0.0;
    return mean / std;
  }
}


