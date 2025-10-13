import 'dart:math' as math;

/// Tracks simple correctness per model to drive adaptive weights.
class PerformanceTracker {
  int dirTotal = 0;
  int dirHits = 0;
  int retTotal = 0;
  int retHits = 0;
  int volTotal = 0;
  int volHits = 0;
  int techTotal = 0;
  int techHits = 0;

  void recordDirection({required String model, required bool hit}) {
    switch (model) {
      case 'dir':
        dirTotal++;
        if (hit) dirHits++;
        break;
      case 'tech':
        techTotal++;
        if (hit) techHits++;
        break;
    }
  }

  void recordReturn({required bool hit}) {
    retTotal++;
    if (hit) retHits++;
  }

  void recordVol({required bool hit}) {
    volTotal++;
    if (hit) volHits++;
  }

  double get accDir => dirTotal == 0 ? 0.5 : dirHits / dirTotal;
  double get accRet => retTotal == 0 ? 0.5 : retHits / retTotal;
  double get accVol => volTotal == 0 ? 0.5 : volHits / volTotal;
  double get accTech => techTotal == 0 ? 0.5 : techHits / techTotal;
}

class Trade {
  final DateTime time;
  final double pnl; // absolute P&L in USDT or normalized units
  const Trade(this.time, this.pnl);
}

class TradingMetrics {
  double winRate;
  double sharpeRatio;
  double maxDrawdown;
  double profitFactor;

  TradingMetrics({
    this.winRate = 0.0,
    this.sharpeRatio = 0.0,
    this.maxDrawdown = 0.0,
    this.profitFactor = 0.0,
  });
}

class TradePerformanceTracker {
  final List<Trade> trades = [];

  void addTrade(Trade trade) {
    trades.add(trade);
    if (trades.length > 100) validateModel();
  }

  TradingMetrics calculateMetrics() {
    if (trades.isEmpty) return TradingMetrics();
    final wins = trades.where((t) => t.pnl > 0).toList();
    final losses = trades.where((t) => t.pnl < 0).toList();
    final winRate = wins.length / trades.length;
    final sharpe = _sharpe(trades.map((t) => t.pnl).toList());
    final mdd = _maxDrawdown(trades.map((t) => t.pnl).toList());
    final totalWins = wins.fold<double>(0.0, (p, t) => p + t.pnl.abs());
    final totalLosses = losses.fold<double>(0.0, (p, t) => p + t.pnl.abs());
    final pf = totalLosses == 0 ? (totalWins > 0 ? double.infinity : 0.0) : totalWins / totalLosses;
    return TradingMetrics(
      winRate: winRate,
      sharpeRatio: sharpe,
      maxDrawdown: mdd,
      profitFactor: pf,
    );
  }

  void validateModel() {
    final m = calculateMetrics();
    if (m.winRate < 0.4 || m.sharpeRatio < 0.5) {
      // TODO: Adjust model weights / position sizing – integrate with RiskManager or ensemble weights
    }
  }

  double _sharpe(List<double> pnlSeries) {
    if (pnlSeries.isEmpty) return 0.0;
    final n = pnlSeries.length;
    final mean = pnlSeries.reduce((a, b) => a + b) / n;
    double variance = 0.0;
    for (final x in pnlSeries) {
      variance += (x - mean) * (x - mean);
    }
    variance /= n;
    final std = variance == 0 ? 0.0 : math.sqrt(variance);
    if (std == 0) return 0.0;
    return mean / std;
  }

  double _maxDrawdown(List<double> pnlSeries) {
    if (pnlSeries.isEmpty) return 0.0;
    double equity = 0.0;
    double peak = 0.0;
    double mdd = 0.0;
    for (final p in pnlSeries) {
      equity += p;
      if (equity > peak) peak = equity;
      final dd = equity - peak; // negative or zero
      if (dd < mdd) mdd = dd;
    }
    return mdd == 0 ? 0.0 : (mdd.abs() / (peak == 0 ? 1.0 : peak));
  }
}
