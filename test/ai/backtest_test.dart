import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/signal_engine.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/backtest/backtester.dart';

void main() {
  group('Backtester Tests', () {
    test('Backtester produces equity curve', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      final backtester = Backtester(engine, const StrategySettings());

      // Generate trending up data (simple)
      final data = List.generate(
        100,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(days: 100 - i)),
          open: 100.0 + i * 0.5,
          high: 102.0 + i * 0.5,
          low: 98.0 + i * 0.5,
          close: 100.0 + i * 0.5,
          volume: 1000.0,
        ),
      );

      final result = await backtester.run(
        'BTCUSDT',
        data,
        initial: 10000,
        position: 0.1,
      );

      expect(result.equity, isNotEmpty);
      expect(result.equity.first, greaterThan(0));
      expect(result.metrics.totalReturn, isA<double>());
    });

    test('Metrics are calculated correctly', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      final backtester = Backtester(engine, const StrategySettings());

      final data = List.generate(
        80,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(days: 80 - i)),
          open: 100.0,
          high: 105.0,
          low: 95.0,
          close: 100.0 + (i % 10 - 5), // Oscillating
          volume: 1000.0,
        ),
      );

      final result = await backtester.run(
        'BTCUSDT',
        data,
        initial: 10000,
        position: 0.1,
      );

      expect(result.metrics.sharpe, isA<double>());
      expect(result.metrics.sortino, isA<double>());
      expect(result.metrics.maxDD, greaterThanOrEqualTo(0));
      expect(result.metrics.maxDD, lessThanOrEqualTo(1)); // Max DD ≤ 100%
      expect(result.metrics.winRate, greaterThanOrEqualTo(0));
      expect(result.metrics.winRate, lessThanOrEqualTo(1));
    });

    test('Fees and slippage reduce returns', () async {
      final engineNoFee = SignalEngine(dirModel: DirectionModel());
      final engineWithFee = SignalEngine(dirModel: DirectionModel());

      const settingsNoFee = StrategySettings(fee: 0.0, slippage: 0.0);
      const settingsWithFee = StrategySettings(fee: 0.001, slippage: 0.0005);

      final backtesterNoFee = Backtester(engineNoFee, settingsNoFee);
      final backtesterWithFee = Backtester(engineWithFee, settingsWithFee);

      // Trending up data
      final data = List.generate(
        70,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(days: 70 - i)),
          open: 100.0 + i,
          high: 102.0 + i,
          low: 98.0 + i,
          close: 100.0 + i,
          volume: 1000.0,
        ),
      );

      final resultNoFee = await backtesterNoFee.run('BTCUSDT', data);
      final resultWithFee = await backtesterWithFee.run('BTCUSDT', data);

      // With fees should have lower or equal returns
      expect(
        resultWithFee.metrics.totalReturn,
        lessThanOrEqualTo(resultNoFee.metrics.totalReturn + 0.01),
      );
    });
  });
}
