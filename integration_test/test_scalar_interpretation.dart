// integration_test/test_scalar_interpretation.dart
// Verifică interpretarea scalarului în DirectionModel (scalar → [buy, hold, sell])

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/models/model_utils.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectionModel (Scalar interpretation)', () {
    test('Bullish synthetic data → favors BUY over SELL', () async {
      final model = DirectionModel();
      final candles = _generateBullish(100);

      // Input sanity
      final feats = ModelUtils.featuresFromCandles(candles, 64, 15);
      expect(feats.length, 64);
      expect(feats.first.length, 15);

      final probs = await model.predictProbs(candles);
      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.02));

      print('\n📈 Scalar-Model Probabilities (bullish):');
      print('  Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      print('  Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      print('  Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      // Expect BUY >= SELL on bullish data (adapter behavior)
      expect(probs[0], greaterThanOrEqualTo(probs[2]));
    });

    test('Bearish synthetic data → favors SELL over BUY', () async {
      final model = DirectionModel();
      final candles = _generateBearish(100);

      final probs = await model.predictProbs(candles);
      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.02));

      print('\n📉 Scalar-Model Probabilities (bearish):');
      print('  Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      print('  Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      print('  Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      // Expect SELL >= BUY on bearish data
      expect(probs[2], greaterThanOrEqualTo(probs[0]));
    });
  });
}

List<Candle> _generateBullish(int n) {
  final rnd = Random(42);
  final out = <Candle>[];
  double price = 40000.0;
  for (int i = 0; i < n; i++) {
    price *= 1.0012 + (rnd.nextDouble() - 0.5) * 0.0006; // mild updrift
    final open = price * 0.9995;
    final close = price;
    final high = max(open, close) * (1 + rnd.nextDouble() * 0.001);
    final low = min(open, close) * (1 - rnd.nextDouble() * 0.001);
    final vol = 1e6 + rnd.nextDouble() * 5e4;
    out.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (n - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
  }
  return out;
}

List<Candle> _generateBearish(int n) {
  final rnd = Random(7);
  final out = <Candle>[];
  double price = 40000.0;
  for (int i = 0; i < n; i++) {
    price *= 0.9988 + (rnd.nextDouble() - 0.5) * 0.0006; // mild downdrift
    final open = price * 1.0005;
    final close = price;
    final high = max(open, close) * (1 + rnd.nextDouble() * 0.0007);
    final low = min(open, close) * (1 - rnd.nextDouble() * 0.0012);
    final vol = 1e6 + rnd.nextDouble() * 5e4;
    out.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (n - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
  }
  return out;
}


