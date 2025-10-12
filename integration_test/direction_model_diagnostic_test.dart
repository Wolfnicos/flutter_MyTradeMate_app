// integration_test/direction_model_diagnostic_test.dart
// Quick harness pentru DirectionModelDebug

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/models/direction_model_debug.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🔬 DirectionModel Diagnostic', () {
    test('Bullish scenario - FULL DIAGNOSTIC', () async {
      print('\n${'=' * 60}');
      print('🔬 STARTING FULL DIAGNOSTIC TEST');
      print('=' * 60 + '\n');

      final model = DirectionModelDebug();
      
      print('🧪 Generating test data (100 bullish candles)...');
      final candles = _generateBullishCandles(100);
      
      print('   First candle: close=${candles.first.close.toStringAsFixed(2)}');
      print('   Last candle:  close=${candles.last.close.toStringAsFixed(2)}');
      print('   Price change: +${((candles.last.close - candles.first.close) / candles.first.close * 100).toStringAsFixed(2)}%');
      
      print('\n${'-' * 60}\n');
      
      // Run prediction with full logging
      final probs = await model.predictProbs(candles);
      
      print('\n${'=' * 60}');
      print('🎯 FINAL RESULT:');
      print('   Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      print('   Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      print('   Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');
      
      final isUniform = (probs[0] - 0.33).abs() < 0.02 &&
                        (probs[1] - 0.33).abs() < 0.02 &&
                        (probs[2] - 0.33).abs() < 0.02;
      
      if (isUniform) {
        print('\n❌ DIAGNOSIS: MODEL IS BROKEN');
        print('   Outputs are uniform (33/33/33)');
        print('\n💡 LIKELY CAUSES:');
        print('   1. Input normalization mismatch (check stats above)');
        print('   2. Model expects different input range');
        print('   3. Model is untrained or corrupted');
        print('   4. Shape mismatch (check tensor info above)');
      } else {
        print('\n✅ DIAGNOSIS: MODEL IS WORKING');
        print('   Outputs are non-uniform and directional');
      }
      
      print('=' * 60 + '\n');
      
      // Cleanup
      model.dispose();
    });

    test('Try FP16 model as alternative', () async {
      print('\n${'=' * 60}');
      print('🔬 TESTING FP16 MODEL');
      print('=' * 60 + '\n');

      // This test helps compare if fp16 model behaves differently
      // You would need to modify DirectionModelDebug to accept model path
      // or create a separate test with fp16 model loaded
      
      print('⚠️  To test FP16 model:');
      print('   1. Modify direction_model_debug.dart line ~20');
      print('   2. Change: direction_f32_builtin.tflite → direction_fp16_builtin.tflite');
      print('   3. Re-run this test');
    });

    test('Bearish scenario - Compare behavior', () async {
      print('\n${'=' * 60}');
      print('🔬 BEARISH SCENARIO TEST');
      print('=' * 60 + '\n');

      final model = DirectionModelDebug();
      
      print('🧪 Generating bearish data...');
      final candles = _generateBearishCandles(100);
      
      print('   First candle: close=${candles.first.close.toStringAsFixed(2)}');
      print('   Last candle:  close=${candles.last.close.toStringAsFixed(2)}');
      print('   Price change: ${((candles.last.close - candles.first.close) / candles.first.close * 100).toStringAsFixed(2)}%');
      
      print('\n${'-' * 60}\n');
      
      final probs = await model.predictProbs(candles);
      
      print('\n🎯 BEARISH RESULT:');
      print('   Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      print('   Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      print('   Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');
      
      final isUniform = (probs[0] - 0.33).abs() < 0.02 &&
                        (probs[1] - 0.33).abs() < 0.02 &&
                        (probs[2] - 0.33).abs() < 0.02;
      
      if (isUniform) {
        print('❌ Still uniform on bearish data');
      } else if (probs[2] > probs[0]) {
        print('✅ Correctly favors SELL on bearish data');
      } else {
        print('⚠️  Non-uniform but doesn\'t favor SELL (unexpected)');
      }
      
      print('=' * 60 + '\n');
      
      model.dispose();
    });
  });
}

List<Candle> _generateBullishCandles(int n) {
  final rnd = Random(42);
  final candles = <Candle>[];
  double price = 40000.0;

  for (int i = 0; i < n; i++) {
    // Strong uptrend: +0.15% per candle
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
    // Downtrend: -0.15% per candle
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


