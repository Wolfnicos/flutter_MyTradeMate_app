import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/indicators.dart';
import 'package:mytrademate/ai/entities.dart';
import 'dart:math';

void main() {
  group('Indicators Tests', () {
    test('EMA calculation is correct', () {
      final values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
      final result = ema(values, 5);

      expect(result, greaterThan(5.0)); // Should be > SMA
      expect(result.isFinite, true);
    });

    test('RSI bounds are 0-100', () {
      // Trending up
      final upTrend = List.generate(30, (i) => 100.0 + i.toDouble());
      final rsiUp = rsi(upTrend, period: 14);

      expect(rsiUp, greaterThanOrEqualTo(0));
      expect(rsiUp, lessThanOrEqualTo(100));
      expect(rsiUp, greaterThan(50)); // Uptrend → RSI > 50

      // Trending down
      final downTrend = List.generate(30, (i) => 100.0 - i.toDouble());
      final rsiDown = rsi(downTrend, period: 14);

      expect(rsiDown, greaterThanOrEqualTo(0));
      expect(rsiDown, lessThanOrEqualTo(100));
      expect(rsiDown, lessThan(50)); // Downtrend → RSI < 50
    });

    test('EWMA volatility is positive', () {
      final closes = List.generate(50, (i) => 100.0 + sin(i / 5.0) * 10);
      final vol = ewmaVol(closes, lambda: 0.94);

      expect(vol, greaterThan(0));
      expect(vol.isFinite, true);
    });

    test('OBV accumulates correctly', () {
      final candles = [
        Candle(
          time: DateTime.now(),
          open: 100,
          high: 105,
          low: 95,
          close: 102,
          volume: 1000,
        ),
        Candle(
          time: DateTime.now(),
          open: 102,
          high: 106,
          low: 100,
          close: 104, // Up → add volume
          volume: 1500,
        ),
        Candle(
          time: DateTime.now(),
          open: 104,
          high: 105,
          low: 99,
          close: 100, // Down → subtract volume
          volume: 800,
        ),
      ];

      final obvValue = obv(candles);

      // OBV = +1500 - 800 = 700
      expect(obvValue, equals(700));
    });

    test('Relative volume calculation', () {
      final candles = List.generate(
        30,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(days: 30 - i)),
          open: 100,
          high: 105,
          low: 95,
          close: 100,
          volume: i < 29 ? 1000.0 : 2000.0, // Last has 2x volume
        ),
      );

      final rv = relativeVolume(candles, period: 20);

      expect(rv, greaterThan(1.5)); // Should be ~2.0
      expect(rv, lessThan(2.5));
    });

    test('Bollinger Bands computed correctly', () {
      final closes = List.generate(30, (i) => 100.0);
      final bb = bollingerBands(closes, period: 20);

      expect(bb.middle, closeTo(100.0, 0.1));
      expect(bb.upper, greaterThan(bb.middle));
      expect(bb.lower, lessThan(bb.middle));
    });
  });
}
