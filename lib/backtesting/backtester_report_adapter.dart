import 'package:flutter/foundation.dart';
import '../ai/ai_locator.dart';
import '../ai/engine_interface.dart';
import '../services/ohlcv_service.dart';
import 'backtester.dart' as v1;
import 'backtest_result.dart' as bt;

class BacktestReport {
  final double initialCapital;
  final double finalCapital;
  final double totalReturn; // percent (e.g., 5.3)
  final int numTrades;
  final int winningTrades;
  final int losingTrades;
  final double avgWin;
  final double avgLoss;
  final double maxDrawdown; // percent
  final double sharpe;
  final double feesPaid;
  final List<DateTime> times;
  final List<double> equity;
  final List<Map<String, dynamic>> trades;

  BacktestReport({
    required this.initialCapital,
    required this.finalCapital,
    required this.totalReturn,
    required this.numTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.avgWin,
    required this.avgLoss,
    required this.maxDrawdown,
    required this.sharpe,
    required this.feesPaid,
    required this.times,
    required this.equity,
    required this.trades,
  });
}

class BacktesterV2 {
  final ISignalEngine engine;
  final OHLCVService ohlcv;
  final String? strategyName; // e.g., 'Hybrid 1: EMA+RSI+Cloud'

  const BacktesterV2({
    required this.engine,
    required this.ohlcv,
    this.strategyName,
  });

  Future<BacktestReport> run({
    required String symbol,
    required String interval,
    required double initialCapital,
    int window = 64,
    int horizon = 1,
    double positionSize = 0.1,
  }) async {
    debugPrint('🚀 BacktesterV2 for $symbol@$interval strategy=$strategyName');
    final core = v1.Backtester(
      engine: engine,
      ohlcv: ohlcv,
      strategyName: strategyName,
    );
    final bt.BacktestResult r = await core.run(
      symbol: symbol,
      interval: interval,
      initialCapital: initialCapital,
      window: window,
      horizon: horizon,
      positionSize: positionSize,
      ensemble: AILocator.I.ensemble,
    );

    // Adapt v1 result → BacktestReport shape
    final trades = r.trades
        .map((t) => {
              'time': t.time,
              'action': t.action,
              'price': t.price,
              'qty': t.qty,
              'fee': t.fee,
              'pnl': t.pnl,
            })
        .toList();

    return BacktestReport(
      initialCapital: r.initialCapital,
      finalCapital: r.finalCapital,
      totalReturn: r.totalReturn * 100.0,
      numTrades: r.numTrades,
      winningTrades: r.winningTrades,
      losingTrades: r.losingTrades,
      avgWin: r.avgWin,
      avgLoss: r.avgLoss,
      maxDrawdown: r.maxDrawdown * 100.0,
      sharpe: r.sharpe,
      feesPaid: r.feesPaid,
      times: r.times,
      equity: r.equity,
      trades: trades,
    );
  }
}


