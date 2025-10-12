import 'package:flutter/foundation.dart';

import '../ai/ai_locator.dart';
import '../ai/engine_interface.dart';
import '../ai/entities.dart';
import '../services/ohlcv_service.dart';
import '../ai/ensemble/ensemble_predictor.dart';
import '../ai/indicators.dart';
// backtest_config.dart unused for now; options passed inline
import 'backtest_result.dart';
import 'metrics_calculator.dart';
import 'trade_simulator.dart';

/// Backtester - runs simulation for a symbol and interval over a custom date range.
class Backtester {
  final ISignalEngine engine;
  final OHLCVService ohlcv;
  final TradeSimulator sim;
  final String? strategyName; // Optional: use simple hybrid-on-single-TF

  const Backtester({
    required this.engine,
    required this.ohlcv,
    this.sim = const TradeSimulator(),
    this.strategyName,
  });

  /// Runs a backtest using the engine and OHLCV service.
  /// The OHLCV service is currently limited to recent candles; for a custom
  /// date range, callers should preload candles and pass via [preloaded].
  Future<BacktestResult> run({
    required String symbol,
    required String interval,
    required double initialCapital,
    List<Candle>? preloaded,
    EnsemblePredictor? ensemble,
    double? positionSize,
    int window = 64,
    int horizon = 1,
  }) async {
    // Startup logs and fixed load size for deterministic behavior
    debugPrint('🚀 Starting backtest for $symbol @ $interval');
    debugPrint(
        '📊 Window=$window, Horizon=$horizon, Ensemble=${ensemble != null}');

    // Load a fixed amount of history unless preloaded is provided
    final candles = preloaded ??
        await ohlcv.fetchCandles(
          symbol,
          interval: interval,
          limit: 2000,
        );
    debugPrint('📊 Loaded ${candles.length} candles for backtest');
    if (candles.length < window + horizon) {
      throw Exception(
          'Not enough candles: ${candles.length} < ${window + horizon}');
    }

    // If positionSize is provided, override simulator's risk per trade
    final execSim = positionSize != null
        ? TradeSimulator(
            feeRate: sim.feeRate,
            slippageRate: sim.slippageRate,
            maxRiskPerTrade: positionSize,
          )
        : sim;

    double capital = initialCapital;
    double positionQty = 0.0;
    double entryPrice = 0.0;
    double totalFees = 0.0;

    int trades = 0;
    int wins = 0;
    int losses = 0;
    double totalWin = 0.0;
    double totalLoss = 0.0;

    final times = <DateTime>[];
    final equity = <double>[];
    final tradeLog = <TradeRecord>[];

    // Determine if we should apply a simple hybrid strategy on this TF
    final useHybridStrategy = strategyName != null &&
        strategyName!.toLowerCase().startsWith('hybrid');
    // Use a simple, predictable ensemble policy – UI/engine control aggressiveness

    for (int i = window; i < candles.length; i++) {
      final look = candles.sublist(i - window, i);
      final close = candles[i].close;

      try {
        String action;
        double confidence;

        if (useHybridStrategy) {
          // Compute simple hybrid 1-like logic on single timeframe
          final closes = look.map((c) => c.close).toList();
          final e12 = ema(closes, 12);
          final e26 = ema(closes, 26);
          final r = rsi(closes, period: 14);
          final cloud = ichimokuCloudSignal(look);

          final emaBull = e12.isFinite && e26.isFinite && e12 > e26;
          final emaBear = e12.isFinite && e26.isFinite && e12 < e26;
          final rsiBull = r.isFinite && r > 50 && r < 70;
          final rsiBear = r.isFinite && r < 50 && r > 30;
          final cloudBull = cloud == 1;
          final cloudBear = cloud == -1;

          final bullSignals =
              [emaBull, rsiBull, cloudBull].where((x) => x).length;
          final bearSignals =
              [emaBear, rsiBear, cloudBear].where((x) => x).length;

          if (bullSignals >= 2) {
            action = 'BUY';
            confidence = bullSignals / 3.0;
          } else if (bearSignals >= 2) {
            action = 'SELL';
            confidence = bearSignals / 3.0;
          } else {
            action = 'HOLD';
            confidence = 0.0;
          }

          if (i % 100 == 0) {
            debugPrint(
                '[$i/${candles.length - horizon}] ${strategyName ?? 'Hybrid'}: $action @ ${(confidence * 100).toStringAsFixed(1)}%');
          }
        } else if (ensemble != null) {
          final er = await ensemble.predict(look);
          final pBuy = er.probs[0];
          final pSell = er.probs[2];

          // Direction-first: ignore HOLD; compare only BUY vs SELL
          if (pBuy > pSell) {
            action = 'BUY';
          } else if (pSell > pBuy) {
            action = 'SELL';
          } else {
            action = 'HOLD'; // only when exactly equal
          }

          // Confidence = probability of chosen action
          confidence = pBuy > pSell ? pBuy : pSell;

          if (i % 100 == 0) {
            debugPrint('[$i/${candles.length - horizon}] '
                'Ensemble: $action @ ${(confidence * 100).toStringAsFixed(1)}% '
                'buy=${(pBuy * 100).toStringAsFixed(0)}% sell=${(pSell * 100).toStringAsFixed(0)}%');
          }
        } else {
          final pred = await engine.predict(symbol, look);
          if (pred == null) continue;
          action = AILocator.I.decide(pred);
          confidence = pred.confidence();

          // Outcome estimation pentru tracker (doar când avem pred de la engine)
          if (ensemble != null && i + horizon < candles.length) {
            final next = candles[i + horizon].close;
            final dirUp = next > close;
            final predUp = pred.pBuy > pred.pSell;
            ensemble.tracker
                .recordDirection(model: 'dir', hit: predUp == dirUp);
          }

          if (i % 100 == 0) {
            debugPrint('['
                '$i/${candles.length - horizon}] '
                'Engine: $action @ ${(confidence * 100).toStringAsFixed(1)}%');
          }
        }

        // Confidence threshold (temporary override)
        const double confThreshold = 0.20;
        if (confidence < confThreshold) {
          final curEquity = capital + positionQty * close;
          times.add(candles[i].time);
          equity.add(curEquity);
          continue;
        }

        // Additional filters removed per request; keep confidence threshold only

        if (positionQty == 0.0 && action == 'BUY') {
          final (newCap, qty, priceWSlip, fee) =
              execSim.buy(capital: capital, price: close);
          capital = newCap;
          positionQty = qty;
          entryPrice = priceWSlip;
          totalFees += fee;
          trades++;
          tradeLog.add(TradeRecord(
              time: candles[i].time,
              action: 'BUY',
              price: priceWSlip,
              qty: qty,
              fee: fee,
              pnl: 0.0));
        } else if (positionQty > 0.0 && action == 'SELL') {
          // Use SL/TP simulation across next N candles
          final start = i + 1;
          final end =
              (start + 25) < candles.length ? (start + 25) : candles.length;
          final futureCandles =
              start < candles.length ? candles.sublist(start, end) : <Candle>[];
          double pnl;
          double exitFee;
          if (futureCandles.isNotEmpty) {
            final positionValue = positionQty * entryPrice;
            pnl = execSim.simulateTrade(
              action: 'BUY', // closing a long position entered via BUY
              entryPrice: entryPrice,
              futureCandles: futureCandles,
              positionValue: positionValue,
            );
            exitFee = positionValue *
                execSim.feeRate; // approximate exit fee used in simulateTrade
            capital += pnl;
          } else {
            final r = execSim.sell(
              capital: capital,
              positionQty: positionQty,
              entryPrice: entryPrice,
              price: close,
            );
            capital = r.$1;
            exitFee = r.$2;
            pnl = r.$3;
          }
          totalFees += exitFee;
          if (pnl > 0) {
            wins++;
            totalWin += pnl;
          } else {
            losses++;
            totalLoss += -pnl;
          }
          positionQty = 0.0;
          tradeLog.add(TradeRecord(
              time: candles[i].time,
              action: 'SELL',
              price: close,
              qty: 0.0,
              fee: exitFee,
              pnl: pnl));
          entryPrice = 0.0;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Backtester step error: $e');
      }

      // mark equity at this step
      final curEquity = capital + positionQty * close;
      times.add(candles[i].time);
      equity.add(curEquity);
    }

    // close open position at last
    if (positionQty > 0.0) {
      final last = candles.last.close;
      final (newCap, fee, pnl) = execSim.sell(
        capital: capital,
        positionQty: positionQty,
        entryPrice: entryPrice,
        price: last,
      );
      capital = newCap;
      totalFees += fee;
      if (pnl > 0) {
        wins++;
        totalWin += pnl;
      } else {
        losses++;
        totalLoss += -pnl;
      }
      tradeLog.add(TradeRecord(
          time: candles.last.time,
          action: 'SELL',
          price: last,
          qty: 0.0,
          fee: fee,
          pnl: pnl));
      final curEquity = capital;
      times.add(candles.last.time);
      equity.add(curEquity);
    }

    final md = MetricsCalculator.maxDrawdown(equity);
    final sharpe = MetricsCalculator.sharpe(equity);
    final finalCap = capital;
    final totalRet = (finalCap - initialCapital) / initialCapital;
    final avgWin = wins > 0 ? totalWin / wins : 0.0;
    final avgLoss = losses > 0 ? totalLoss / losses : 0.0;

    return BacktestResult(
      start: candles.first.time,
      end: candles.last.time,
      symbol: symbol,
      interval: interval,
      times: times,
      equity: equity,
      initialCapital: initialCapital,
      finalCapital: finalCap,
      totalReturn: totalRet,
      numTrades: trades,
      winningTrades: wins,
      losingTrades: losses,
      avgWin: avgWin,
      avgLoss: avgLoss,
      maxDrawdown: md,
      sharpe: sharpe,
      feesPaid: totalFees,
      trades: tradeLog,
    );
  }
}
