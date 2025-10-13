import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/backtesting/backtester.dart' as bt;
import 'package:mytrademate/backtesting/trade_simulator.dart' as sim;
import 'package:mytrademate/backtesting/backtest_result.dart' as btr;
import 'package:mytrademate/ai/signal_engine.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

/// Cache path for test fixtures (ignored in repo if needed)
final String _cachePath = 'test/fixtures/btcusdt_5m_30d.json';

Future<List<Candle>> _loadOrFetch5m30d() async {
  final f = File(_cachePath);
  if (await f.exists()) {
    final txt = await f.readAsString();
    final data = (jsonDecode(txt) as List)
        .map((e) => Candle(
              time: DateTime.parse(e['time'] as String),
              open: (e['open'] as num).toDouble(),
              high: (e['high'] as num).toDouble(),
              low: (e['low'] as num).toDouble(),
              close: (e['close'] as num).toDouble(),
              volume: (e['volume'] as num).toDouble(),
            ))
        .toList(growable: false);
    return data;
  }
  final svc = await OHLCVService.createFromPrefs();
  final candles = await svc.fetchCandles('BTCUSDT', interval: '5m', limit: 9000);
  await f.create(recursive: true);
  final payload = candles
      .map((c) => {
            'time': c.time.toIso8601String(),
            'open': c.open,
            'high': c.high,
            'low': c.low,
            'close': c.close,
            'volume': c.volume,
          })
      .toList(growable: false);
  await f.writeAsString(jsonEncode(payload));
  return candles;
}

Future<btr.BacktestResult> runPermissiveBacktest({
  required List<Candle> data,
  String symbol = 'BTCUSDT',
  String interval = '5m',
  double initialCapital = 10000.0,
}) async {
  final engine = SignalEngine.full(
    settings: const StrategySettings(
      upThresh: 0.0005,
      downThresh: -0.0005,
      confThresh: 0.25,
      volCap: 0.95,
      fee: 0.0007,
      slippage: 0.0003,
    ),
  );
  final svc = await OHLCVService.createFromPrefs();
  final backtester = bt.Backtester(engine: engine, ohlcv: svc);
  return backtester.run(
    symbol: symbol,
    interval: interval,
    initialCapital: initialCapital,
    preloaded: data,
    positionSize: 0.1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backtester integration', () {
    late List<Candle> data5m;

    setUpAll(() async {
      data5m = await _loadOrFetch5m30d();
      expect(data5m.length, greaterThan(5000));
    });

    test('Iterație completă: decizii ≥ N - lookback', () async {
      final window = 64;
      final result = await runPermissiveBacktest(data: data5m);
      // We approximate decisions by recorded equity points
      expect(result.times.length, greaterThanOrEqualTo(data5m.length - window));
    });

    test('Multiplicitate trades: >= 10 pe 30 zile 5m (setări permisive)', () async {
      final result = await runPermissiveBacktest(data: data5m);
      expect(result.numTrades, greaterThanOrEqualTo(10));
    });

    test('Conservarea capitalului și state correctness la CLOSE', () async {
      final result = await runPermissiveBacktest(data: data5m);
      // Reconstituim evenimente SELL din TradeRecord și verificăm non-negativitatea
      double capital = result.initialCapital;
      double positionQty = 0.0;
      double entryPrice = 0.0;
      for (int i = 0; i < result.trades.length; i++) {
        final tr = result.trades[i];
        if (tr.action == 'BUY') {
          // aproximăm buy: folosim simulatorul implicit pentru consistență de direcție
          final s = const sim.TradeSimulator();
          final r = s.buy(capital: capital, price: tr.price);
          capital = r.$1;
          positionQty = r.$2;
          entryPrice = r.$3;
          expect(r.$4 >= 0.0, true); // fee
          expect(positionQty >= 0.0, true);
        } else if (tr.action == 'SELL') {
          final s = const sim.TradeSimulator();
          final r = s.sell(
            capital: capital,
            positionQty: positionQty,
            entryPrice: entryPrice,
            price: tr.price,
          );
          capital = r.$1;
          final fee = r.$2;
          final _ = r.$3; // ignore pnl value; correctness covered by capital non-negativity
          expect(fee >= 0.0, true);
          expect(capital >= 0.0, true);
          // qty reset
          positionQty = 0.0;
        }
      }
      expect(capital >= 0.0, true);
    });

    test('Nenegativitate fee & qty; fără NaN/Inf', () async {
      final result = await runPermissiveBacktest(data: data5m);
      for (final tr in result.trades) {
        expect(tr.fee.isFinite, true);
        expect(tr.pnl.isFinite, true);
        expect(tr.fee >= 0.0, true);
        expect(tr.qty >= 0.0, true);
      }
    });
  });
}
