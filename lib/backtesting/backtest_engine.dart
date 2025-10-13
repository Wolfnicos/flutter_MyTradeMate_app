import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/backtesting/backtest_result.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

class BacktestPeriod {
  final DateTime start;
  final DateTime end;
  final String interval;
  const BacktestPeriod({required this.start, required this.end, required this.interval});
}

class BacktestResults {
  final List<BacktestResult> periods = [];

  void merge(BacktestResult r) => periods.add(r);

  double get sharpeRatioAvg => periods.isEmpty
      ? 0.0
      : periods.map((p) => p.sharpe).reduce((a, b) => a + b) / periods.length;

  double get maxDrawdownWorst => periods.isEmpty
      ? 0.0
      : periods.map((p) => p.maxDrawdown).reduce((a, b) => a > b ? a : b);

  double get winRate => periods.isEmpty
      ? 0.0
      : periods
              .map((p) => p.winningTrades)
              .reduce((a, b) => a + b) /
          (periods.map((p) => p.numTrades).reduce((a, b) => a + b) == 0
              ? 1
              : periods.map((p) => p.numTrades).reduce((a, b) => a + b));
}

class BacktestEngine {
  Future<BacktestResults> runBacktest(
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic> parameters,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    await AILocator.I.init();
    final results = BacktestResults();
    final symbol = (parameters['symbol'] ?? 'BTCUSDT').toString();
    final interval = (parameters['interval'] ?? '5m').toString();
    final initialCapital = (parameters['initialCapital'] ?? 10000.0) as double;

    final ohlcv = await OHLCVService.createFromPrefs();
    final periods = _getWalkForwardPeriods(startDate, endDate, interval);
    final engine = AILocator.I.engine;
    final bt = Backtester(engine: engine, ohlcv: ohlcv);

    for (final period in periods) {
      try {
        final candles = await ohlcv.fetchCandles(symbol,
            interval: period.interval,
            limit: 2000,
            forceQuote: true);
        // Filter to period window
        final filtered = candles
            .where((c) => !c.time.isBefore(period.start) && !c.time.isAfter(period.end))
            .toList();
        if (filtered.length < 100) continue;
        final r = await bt.run(
          symbol: symbol,
          interval: period.interval,
          initialCapital: initialCapital,
          preloaded: filtered,
        );
        results.merge(r);
        if (r.sharpe < 0.3) {
          debugPrint('⚠️ Poor performance in ${period.start} - ${period.end} (Sharpe ${r.sharpe.toStringAsFixed(2)})');
        }
      } catch (e) {
        debugPrint('Backtest period error: $e');
      }
    }

    return results;
  }

  List<BacktestPeriod> _getWalkForwardPeriods(
      DateTime start, DateTime end, String interval) {
    final periods = <BacktestPeriod>[];
    DateTime cur = DateTime(start.year, start.month, start.day);
    while (cur.isBefore(end)) {
      final next = DateTime(cur.year, cur.month + 1, cur.day);
      final pEnd = next.isBefore(end) ? next : end;
      periods.add(BacktestPeriod(start: cur, end: pEnd, interval: interval));
      cur = next;
    }
    return periods;
  }
}


