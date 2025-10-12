import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/backtesting/trade_simulator.dart';
import 'package:mytrademate/ai/engine_interface.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

class _FakeEngine implements ISignalEngine {
  @override
  void dispose() {}

  @override
  String decide(Prediction p) {
    if (p.pBuy > p.pSell && p.pBuy > 0.4) return 'BUY';
    if (p.pSell > p.pBuy && p.pSell > 0.4) return 'SELL';
    return 'HOLD';
  }

  @override
  Future<Prediction?> predict(String symbol, List<Candle> window) async {
    // Simple momentum: favor BUY if last close above first by >0.3%
    final first = window.first.close;
    final last = window.last.close;
    final r = (last - first) / first;
    if (r > 0.003) {
      return Prediction(
        symbol: symbol,
        asOf: window.last.time,
        pBuy: 0.6,
        pHold: 0.3,
        pSell: 0.1,
        expReturn: 0.002,
        annVol: 0.2,
        relVolume: 1.0,
      );
    } else if (r < -0.003) {
      return Prediction(
        symbol: symbol,
        asOf: window.last.time,
        pBuy: 0.1,
        pHold: 0.3,
        pSell: 0.6,
        expReturn: -0.002,
        annVol: 0.2,
        relVolume: 1.0,
      );
    }
    return Prediction(
      symbol: symbol,
      asOf: window.last.time,
      pBuy: 0.33,
      pHold: 0.34,
      pSell: 0.33,
      expReturn: 0.0,
      annVol: 0.15,
      relVolume: 1.0,
    );
  }
}

void main() {
  test('Backtester produces equity curve and metrics', () async {
    // Build synthetic candles with gentle uptrend
    final candles = <Candle>[];
    double price = 100.0;
    final now = DateTime.now();
    for (int i = 0; i < 200; i++) {
      price *= 1.0008; // drift up
      candles.add(Candle(
        time: now.add(Duration(minutes: i * 5)),
        open: price * 0.999,
        high: price * 1.001,
        low: price * 0.999,
        close: price,
        volume: 1000 + i.toDouble(),
      ));
    }

    final engine = _FakeEngine();
    final bt = Backtester(
      engine: engine,
      ohlcv: await OHLCVService.createFromPrefs(),
      sim: const TradeSimulator(
          feeRate: 0.001, slippageRate: 0.0005, maxRiskPerTrade: 0.02),
    );

    final res = await bt.run(
      symbol: 'BTCUSDT',
      interval: '5m',
      initialCapital: 10000,
      preloaded: candles,
    );

    expect(res.equity.length, greaterThan(0));
    expect(res.numTrades, greaterThanOrEqualTo(1));
    expect(res.finalCapital, greaterThan(0));
    expect(res.maxDrawdown, inExclusiveRange(0.0, 1.0));
  });
}
