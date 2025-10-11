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

  /// Merit Score = (Expected Return * Win Rate * Portfolio Impact)
  ///                / (Max Drawdown * Risk * Time Commitment)
  /// All inputs are expected as fractions (e.g., 0.12 = 12%).
  static double meritScore({
    required double expectedReturn,
    required double winRate,
    required double portfolioImpact,
    required double maxDrawdown,
    required double risk,
    required double timeCommitment,
  }) {
    const double eps = 1e-9;
    final num = (expectedReturn.clamp(-1.0, 10.0)) *
        (winRate.clamp(0.0, 1.0)) *
        (portfolioImpact.clamp(0.0, 10.0));
    final den = (maxDrawdown.abs().clamp(eps, 10.0)) *
        (risk.clamp(eps, 10.0)) *
        (timeCommitment.clamp(eps, 10.0));
    return (num / den).isFinite ? (num / den) : 0.0;
  }

  /// Convenience: compute Merit Score from a backtest result.
  /// Assumptions:
  /// - expectedReturn uses totalReturn (fraction)
  /// - winRate computed from wins/numTrades (0..1)
  /// - portfolioImpact/risk/timeCommitment are user-tunable scalars (default 1)
  static double meritFromBacktest(
    List<double> equity, {
    required double totalReturn,
    required int wins,
    required int trades,
    required double maxDd,
    double portfolioImpact = 1.0,
    double risk = 1.0,
    double timeCommitment = 1.0,
  }) {
    final wr = trades > 0 ? (wins / trades) : 0.0;
    final exp = totalReturn; // already fraction
    final dd = maxDd;
    return meritScore(
      expectedReturn: exp,
      winRate: wr,
      portfolioImpact: portfolioImpact,
      maxDrawdown: dd,
      risk: risk,
      timeCommitment: timeCommitment,
    );
  }

  /// Classify Merit Score by thresholds
  static String meritDecision(double score) {
    if (score > 8.0) return 'Implementare imediată';
    if (score >= 5.0) return 'Backtesting extins';
    return 'Respinge';
  }
}


