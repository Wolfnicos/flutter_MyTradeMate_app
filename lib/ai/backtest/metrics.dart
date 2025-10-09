import 'dart:math';

/// Metrics - Performance metrics pentru backtesting
class Metrics {
  final double totalReturn;   // Total return (ex: 0.25 = +25%)
  final double cagr;           // Compound Annual Growth Rate
  final double sharpe;         // Sharpe Ratio (risk-adjusted return)
  final double sortino;        // Sortino Ratio (downside risk)
  final double maxDD;          // Maximum Drawdown (worst peak-to-trough)
  final double winRate;        // Win rate (% profitable periods)
  final int totalTrades;       // Total number of trades
  final int winningTrades;     // Number of winning trades
  final int losingTrades;      // Number of losing trades

  const Metrics({
    required this.totalReturn,
    required this.cagr,
    required this.sharpe,
    required this.sortino,
    required this.maxDD,
    required this.winRate,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
  });

  /// Calculate metrics from equity curve
  factory Metrics.fromEquity(
    List<double> equity, {
    int? trades,
    int? wins,
    int? losses,
  }) {
    if (equity.isEmpty) {
      return const Metrics(
        totalReturn: 0,
        cagr: 0,
        sharpe: 0,
        sortino: 0,
        maxDD: 0,
        winRate: 0,
        totalTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
      );
    }

    // Total return
    final totalRet = (equity.last / equity.first) - 1.0;

    // Daily returns
    final rets = <double>[];
    for (int i = 1; i < equity.length; i++) {
      rets.add((equity[i] / equity[i - 1]) - 1.0);
    }

    // Mean daily return
    final meanRet = rets.isEmpty 
        ? 0.0 
        : rets.reduce((a, b) => a + b) / rets.length;

    // Volatility (std dev of returns)
    final variance = rets.isEmpty
        ? 0.0
        : rets.map((r) => pow(r - meanRet, 2)).reduce((a, b) => a + b) / rets.length;
    final vol = sqrt(variance);

    // Downside deviation (only negative returns)
    final downsideReturns = rets.where((r) => r < 0).toList();
    final downsideVariance = downsideReturns.isEmpty
        ? 0.0
        : downsideReturns.map((r) => pow(r, 2)).reduce((a, b) => a + b) / downsideReturns.length;
    final downsideVol = sqrt(downsideVariance);

    // Sharpe Ratio (anualizat, assume rf = 0)
    final sharpe = vol == 0 ? 0.0 : (meanRet * 365) / (vol * sqrt(365));

    // Sortino Ratio (anualizat)
    final sortino = downsideVol == 0 ? 0.0 : (meanRet * 365) / (downsideVol * sqrt(365));

    // Maximum Drawdown
    double peak = equity.first;
    double mdd = 0.0;
    for (final value in equity) {
      peak = max(peak, value);
      final dd = (value / peak) - 1.0;
      mdd = min(mdd, dd);
    }

    // Win Rate
    final wins = rets.where((r) => r > 0).length;
    final winRate = rets.isEmpty ? 0.0 : wins / rets.length;

    // CAGR (Compound Annual Growth Rate)
    final nDays = equity.length;
    final years = nDays / 365.0;
    final cagr = years > 0 ? pow(equity.last / equity.first, 1.0 / years) - 1.0 : 0.0;

    return Metrics(
      totalReturn: totalRet,
      cagr: cagr.toDouble(),
      sharpe: sharpe,
      sortino: sortino,
      maxDD: mdd.abs(),
      winRate: winRate,
      totalTrades: trades ?? 0,
      winningTrades: wins,
      losingTrades: rets.length - wins,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalReturn': totalReturn,
        'cagr': cagr,
        'sharpe': sharpe,
        'sortino': sortino,
        'maxDD': maxDD,
        'winRate': winRate,
        'totalTrades': totalTrades,
        'winningTrades': winningTrades,
        'losingTrades': losingTrades,
      };

  @override
  String toString() {
    return '''
Backtest Metrics:
  Total Return: ${(totalReturn * 100).toStringAsFixed(2)}%
  CAGR: ${(cagr * 100).toStringAsFixed(2)}%
  Sharpe Ratio: ${sharpe.toStringAsFixed(2)}
  Sortino Ratio: ${sortino.toStringAsFixed(2)}
  Max Drawdown: ${(maxDD * 100).toStringAsFixed(2)}%
  Win Rate: ${(winRate * 100).toStringAsFixed(2)}%
  Total Trades: $totalTrades
  Winning: $winningTrades | Losing: $losingTrades
    ''';
  }
}


