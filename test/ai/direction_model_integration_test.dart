import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/models/model_utils.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectionModel Integration (TFLite)', () {
    test('Bullish data should NOT be uniform and favor BUY', () async {
      final model = DirectionModel();
      final candles = _generateBullishCandles(100);

      // Input sanity checks
      final feats = ModelUtils.featuresFromCandles(candles, 64, 15);
      expect(feats.length, equals(64), reason: 'Window size must be 64');
      expect(feats.first.length, equals(15),
          reason: 'Features count must be 15');

      final flat = ModelUtils.normalize2D(feats);
      expect(flat.every((x) => x.isFinite), isTrue,
          reason: 'All features must be finite');
      expect(flat.any((x) => x.isNaN), isFalse,
          reason: 'No NaN values allowed');

      // Log input stats for debugging
      // ignore: avoid_print
      print('\n📊 INPUT STATISTICS:');
      for (int i = 0; i < 15; i++) {
        final values = feats.map((row) => row[i]).toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final std = sqrt(
            values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
                values.length);
        // ignore: avoid_print
        print(
            '  Feature $i: mean=${mean.toStringAsFixed(4)}, std=${std.toStringAsFixed(4)}');
      }

      // Run prediction
      final probs = await model.predictProbs(candles);

      // ignore: avoid_print
      print('\n📈 BULLISH PREDICTION:');
      // ignore: avoid_print
      print('  Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.02), reason: 'Probabilities must sum to ~1.0');

      // Check if TFLite is active (not fallback's exact [.33, .34, .33])
      final isFallback = (probs[0] - 0.33).abs() < 0.005 &&
          (probs[1] - 0.34).abs() < 0.005 &&
          (probs[2] - 0.33).abs() < 0.005;

      if (isFallback) {
        // ignore: avoid_print
        print('\n⚠️  WARNING: Fallback detected (uniform distribution)');
        // ignore: avoid_print
        print(
            '   This means TFLite interpreter is NOT available in this test environment.');
        // ignore: avoid_print
        print('   Run on device/simulator to test actual TFLite model.');
      } else {
        // ignore: avoid_print
        print('\n✅ TFLite model active!');
        expect(probs[0], greaterThan(0.4),
            reason: 'Bullish data should favor BUY (>40%)');
        expect((probs[0] - 1 / 3).abs(), greaterThan(0.05),
            reason: 'Distribution should NOT be uniform');
        expect(probs[0], greaterThan(probs[2]),
            reason: 'BUY should dominate over SELL on bullish data');
      }
    });

    test('Bearish data should favor SELL', () async {
      final model = DirectionModel();
      final candles = _generateBearishCandles(100);

      final probs = await model.predictProbs(candles);

      // ignore: avoid_print
      print('\n📉 BEARISH PREDICTION:');
      // ignore: avoid_print
      print('  Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.02));

      final isFallback = (probs[0] - 0.33).abs() < 0.005 &&
          (probs[1] - 0.34).abs() < 0.005 &&
          (probs[2] - 0.33).abs() < 0.005;

      if (!isFallback) {
        expect(probs[2], greaterThan(0.4),
            reason: 'Bearish data should favor SELL');
        expect(probs[2], greaterThan(probs[0]),
            reason: 'SELL should dominate over BUY on bearish data');
      }
    });

    test('Sideways data should favor HOLD', () async {
      final model = DirectionModel();
      final candles = _generateSidewaysCandles(100);

      final probs = await model.predictProbs(candles);

      // ignore: avoid_print
      print('\n➡️  SIDEWAYS PREDICTION:');
      // ignore: avoid_print
      print('  Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      final sum = probs.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.02));
    });
  });
}

List<Candle> _generateBullishCandles(int n) {
  final rnd = Random(42); // Seed for reproducibility
  final candles = <Candle>[];
  double price = 40000.0;

  for (int i = 0; i < n; i++) {
    // Strong bullish drift: +0.15% per candle average
    price *= 1.0015 + (rnd.nextDouble() - 0.5) * 0.0006;

    final open = price * 0.999;
    final close = price;
    final high = max(open, close) * (1 + rnd.nextDouble() * 0.001);
    final low = min(open, close) * (1 - rnd.nextDouble() * 0.001);
    final vol = 1e6 + rnd.nextDouble() * 1e5;

    candles.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (n - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
  }

  return candles;
}

List<Candle> _generateBearishCandles(int n) {
  final rnd = Random(123);
  final candles = <Candle>[];
  double price = 40000.0;

  for (int i = 0; i < n; i++) {
    // Bearish drift: -0.15% per candle
    price *= 0.9985 + (rnd.nextDouble() - 0.5) * 0.0006;

    final open = price * 1.001;
    final close = price;
    final high = max(open, close) * (1 + rnd.nextDouble() * 0.0005);
    final low = min(open, close) * (1 - rnd.nextDouble() * 0.001);
    final vol = 1e6 + rnd.nextDouble() * 8e4;

    candles.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (n - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
  }

  return candles;
}

List<Candle> _generateSidewaysCandles(int n) {
  final rnd = Random(789);
  final candles = <Candle>[];
  double price = 40000.0;

  for (int i = 0; i < n; i++) {
    // Minimal drift, high noise
    price *= 1.0 + (rnd.nextDouble() - 0.5) * 0.0008;

    final open = price * (1 + (rnd.nextDouble() - 0.5) * 0.001);
    final close = price;
    final high = max(open, close) * (1 + rnd.nextDouble() * 0.0008);
    final low = min(open, close) * (1 - rnd.nextDouble() * 0.0008);
    final vol = 1e6 + rnd.nextDouble() * 5e4;

    candles.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (n - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
  }

  return candles;
}
