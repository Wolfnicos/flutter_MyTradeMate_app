import 'dart:math' as math;

import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/vision_predictor.dart';
import 'package:mytrademate/vision/chart_capture_service.dart';

class VisionModelValidator {
  Future<void> validateModel() async {
    final testCases = [
      {'symbol': 'BTCUSDT', 'pattern': 'uptrend', 'expected': const [0.8, 0.1, 0.1]},
      {'symbol': 'ETHUSDT', 'pattern': 'downtrend', 'expected': const [0.1, 0.1, 0.8]},
      {'symbol': 'BNBUSDT', 'pattern': 'sideways', 'expected': const [0.3, 0.4, 0.3]},
    ];

    for (final testCase in testCases) {
      final result = await predictForTestCase(testCase);
      final expected = (testCase['expected'] as List).map((e) => (e as num).toDouble()).toList();
      final deviation = calculateDeviation(result, expected);
      // ignore: avoid_print
      print('[Vision-Validate] ${(testCase['symbol'])} ${(testCase['pattern'])} → probs=${result.map((e)=>e.toStringAsFixed(3)).toList()} dev=${deviation.toStringAsFixed(3)}');
      if (deviation > 0.5) {
        // ignore: avoid_print
        print('[Model-Warning] High deviation for ${testCase['symbol']}: ${deviation.toStringAsFixed(3)}');
      }
    }
  }

  Future<List<double>> predictForTestCase(Map<String, Object> testCase) async {
    // Only 'pattern' is needed for synthetic generation
    final pattern = testCase['pattern'] as String;
    final candles = _generateSyntheticCandles(pattern: pattern);
    final frame = await ChartCaptureService.renderCandlesImage(candles: candles, width: 320, height: 200);
    await VisionPredictor.I.ensureLoaded();
    final probs = await VisionPredictor.I.predictProbsRGB(
      rgbBytes: frame.bytes,
      width: frame.width,
      height: frame.height,
    );
    return probs;
  }

  double calculateDeviation(List<double> result, List<double> expected) {
    double d = 0.0;
    final n = math.min(result.length, expected.length);
    for (int i = 0; i < n; i++) {
      d += (result[i] - expected[i]).abs();
    }
    return d / n; // average absolute deviation
  }

  List<Candle> _generateSyntheticCandles({required String pattern, int length = 96, double start = 100.0}) {
    final rnd = math.Random(42);
    final candles = <Candle>[];
    double price = start;
    for (int i = 0; i < length; i++) {
      double drift;
      double noise;
      switch (pattern) {
        case 'uptrend':
          drift = 0.002; // +0.2% per bar
          noise = (rnd.nextDouble() - 0.5) * 0.002;
          break;
        case 'downtrend':
          drift = -0.002; // -0.2% per bar
          noise = (rnd.nextDouble() - 0.5) * 0.002;
          break;
        default:
          drift = 0.0;
          noise = (rnd.nextDouble() - 0.5) * 0.001;
      }
      final ret = drift + noise;
      final open = price;
      price = price * (1.0 + ret);
      final close = price;
      final high = math.max(open, close) * (1.0 + 0.001 + rnd.nextDouble() * 0.002);
      final low = math.min(open, close) * (1.0 - 0.001 - rnd.nextDouble() * 0.002);
      final vol = 1000.0 + rnd.nextDouble() * 500.0;
      candles.add(Candle(
        time: DateTime.fromMillisecondsSinceEpoch(1700000000000 + i * 300000),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: vol,
      ));
    }
    return candles;
  }
}


