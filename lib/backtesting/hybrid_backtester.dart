import 'package:flutter/foundation.dart';
import 'package:mytrademate/ai/ai_config.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/strategies/hybrid_strategies.dart' as hs;
import 'package:mytrademate/backtesting/backtest_result.dart';
import 'package:mytrademate/backtesting/metrics_calculator.dart';
import 'package:mytrademate/backtesting/trade_simulator.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

class HybridBacktester {
  final OHLCVService ohlcv;
  final TradeSimulator sim;

  const HybridBacktester({
    required this.ohlcv,
    this.sim = const TradeSimulator(),
  });

  /// strategy: 'hybrid1' .. 'hybrid5'
  Future<BacktestResult> run({
    required String symbol,
    required String strategy,
    required double initialCapital,
    double? positionSize,
    int window = 64,
  }) async {
    // Fetch needed timeframes
    final needs15m = strategy == 'hybrid3';
    final needs1h = strategy == 'hybrid2' || strategy == 'hybrid4';
    final needs4h =
        strategy == 'hybrid1' || strategy == 'hybrid3' || strategy == 'hybrid5';
    final needs5m = strategy != 'hybrid3';
    const needs1d = true;

    if (kDebugMode) {
      debugPrint('🧪 HybridBacktester($strategy) for $symbol');
    }

    final List<Candle> tf5m = needs5m
        ? await ohlcv.fetchCandles(symbol, interval: '5m', limit: 2000)
        : <Candle>[];
    final List<Candle> tf15m = needs15m
        ? await ohlcv.fetchCandles(symbol, interval: '15m', limit: 2000)
        : <Candle>[];
    final List<Candle> tf1h = needs1h
        ? await ohlcv.fetchCandles(symbol, interval: '1h', limit: 2000)
        : <Candle>[];
    final List<Candle> tf4h = needs4h
        ? await ohlcv.fetchCandles(symbol, interval: '4h', limit: 2000)
        : <Candle>[];
    final List<Candle> tf1d = needs1d
        ? await ohlcv.fetchCandles(symbol, interval: '1d', limit: 2000)
        : <Candle>[];

    final base = strategy == 'hybrid3' ? tf15m : tf5m;
    if (base.length < window + 2) {
      throw Exception('Not enough base candles for $strategy: ${base.length}');
    }

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

    final execSim = positionSize != null
        ? TradeSimulator(
            feeRate: sim.feeRate,
            slippageRate: sim.slippageRate,
            maxRiskPerTrade: positionSize,
          )
        : sim;

    for (int i = window; i < base.length; i++) {
      final t = base[i].time;
      // Select aligned windows up to current time
      List<Candle> upto(List<Candle> src) => src
          .where((c) => c.time.isBefore(t) || c.time.isAtSameMomentAs(t))
          .toList();

      final s5 = needs5m ? upto(tf5m) : const <Candle>[];
      final s15 = needs15m ? upto(tf15m) : const <Candle>[];
      final s1h = needs1h ? upto(tf1h) : const <Candle>[];
      final s4h = needs4h ? upto(tf4h) : const <Candle>[];
      final s1d = needs1d ? upto(tf1d) : const <Candle>[];

      String action = 'HOLD';
      double confidence = 0.0;
      try {
        Map<String, dynamic> res;
        switch (strategy) {
          case 'hybrid1':
            res = hs.hybridStrategy1(tf5m: s5, tf4h: s4h, tf1d: s1d);
            break;
          case 'hybrid2':
            res = hs.hybridStrategy2(tf5m: s5, tf1h: s1h, tf1d: s1d);
            break;
          case 'hybrid3':
            res = hs.hybridStrategy3(tf15m: s15, tf4h: s4h, tf1d: s1d);
            break;
          case 'hybrid4':
            res = hs.hybridStrategy4(tf5m: s5, tf1h: s1h, tf1d: s1d);
            break;
          case 'hybrid5':
            res = hs.hybridStrategy5(tf5m: s5, tf4h: s4h, tf1d: s1d);
            break;
          default:
            res = {'action': 'HOLD', 'confidence': 0.0};
        }
        action = (res['action'] ?? 'HOLD') as String;
        confidence = (res['confidence'] ?? 0.0) as double;
      } catch (e) {
        if (kDebugMode) debugPrint('Hybrid strategy error: $e');
        action = 'HOLD';
        confidence = 0.0;
      }

      final close = base[i].close;

      // Confidence threshold from AiConfig
      if (confidence < AiConfig.confThresh) {
        final curEq = capital + positionQty * close;
        times.add(base[i].time);
        equity.add(curEq);
        continue;
      }

      if (positionQty == 0.0 && action == 'BUY') {
        final (newCap, qty, priceWSlip, fee) =
            execSim.buy(capital: capital, price: close);
        capital = newCap;
        positionQty = qty;
        entryPrice = priceWSlip;
        totalFees += fee;
        trades++;
        tradeLog.add(TradeRecord(
            time: base[i].time,
            action: 'BUY',
            price: priceWSlip,
            qty: qty,
            fee: fee,
            pnl: 0.0));
      } else if (positionQty > 0.0 && action == 'SELL') {
        final (newCap, fee, pnl) = execSim.sell(
          capital: capital,
          positionQty: positionQty,
          entryPrice: entryPrice,
          price: close,
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
        positionQty = 0.0;
        tradeLog.add(TradeRecord(
            time: base[i].time,
            action: 'SELL',
            price: close,
            qty: 0.0,
            fee: fee,
            pnl: pnl));
        entryPrice = 0.0;
      }

      final curEq = capital + positionQty * close;
      times.add(base[i].time);
      equity.add(curEq);
    }

    if (positionQty > 0.0) {
      final last = base.last.close;
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
      times.add(base.last.time);
      equity.add(capital);
    }

    final md = MetricsCalculator.maxDrawdown(equity);
    final sharpe = MetricsCalculator.sharpe(equity);
    final totalRet = (capital - initialCapital) / initialCapital;

    return BacktestResult(
      start: base.first.time,
      end: base.last.time,
      symbol: symbol,
      interval: strategy == 'hybrid3' ? '15m' : '5m',
      times: times,
      equity: equity,
      initialCapital: initialCapital,
      finalCapital: capital,
      totalReturn: totalRet,
      numTrades: trades,
      winningTrades: wins,
      losingTrades: losses,
      avgWin: wins > 0 ? totalWin / wins : 0.0,
      avgLoss: losses > 0 ? totalLoss / losses : 0.0,
      maxDrawdown: md,
      sharpe: sharpe,
      feesPaid: totalFees,
      trades: tradeLog,
    );
  }
}
