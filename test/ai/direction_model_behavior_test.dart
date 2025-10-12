import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  group('DirectionModel behavior', () {
    test('should favor BUY on bullish synthetic candles', () async {
      final model = DirectionModel();

      // Generate synthetic bullish candles
      final candles = _generateBullishCandles(100);

      final probs = await model.predictProbs(candles);

      // Expect BUY > HOLD and not uniform 1/3
      expect(probs[0], greaterThan(0.4));
      expect(probs[1], lessThan(0.4));
    });
  });
}

List<Candle> _generateBullishCandles(int count) {
  final candles = <Candle>[];
  double price = 40000.0;
  final rand = Random(42);

  for (int i = 0; i < count; i++) {
    // Gentle bullish drift to keep RSI between ~50-70
    price += 2.0 + rand.nextDouble() * 1.0;
    final open = price - 1.5;
    final high = price + 2.0;
    final low = price - 2.0;
    final close = price;
    // Keep volume roughly constant so volume_rel ~ 1.0 (avoid Rule 2 triggers)
    final volume = 1000000 + rand.nextDouble() * 10000;
    candles.add(Candle(
      time: DateTime.now().subtract(Duration(minutes: (count - i) * 5)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    ));
  }

  return candles;
}
