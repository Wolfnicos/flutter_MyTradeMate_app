// integration_test/test_all_direction_models.dart
// Quick test pentru TOATE variantele de direction model

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:mytrademate/ai/models/model_utils.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final modelPaths = [
    'assets/models/direction_f32_builtin.tflite',
    'assets/models/direction_fp16_builtin.tflite',
    'assets/models/direction_int8_builtin.tflite',
  ];

  group('🔬 Test All Direction Model Variants', () {
    for (final modelPath in modelPaths) {
      test('Test $modelPath', () async {
        print('\n' + '=' * 70);
        print('📦 TESTING: $modelPath');
        print('=' * 70);

        try {
          final interpreter = await Interpreter.fromAsset(modelPath);

          // Log tensor info
          final inputTensors = interpreter.getInputTensors();
          final outputTensors = interpreter.getOutputTensors();

          print('\n📊 TENSOR INFO:');
          print('   Input tensors: ${inputTensors.length}');
          for (var i = 0; i < inputTensors.length; i++) {
            final tensor = inputTensors[i];
            print('   Input[$i]:');
            print('     - Shape: ${tensor.shape}');
            print('     - Type: ${tensor.type}');
            print('     - Name: ${tensor.name}');
          }

          print('\n   Output tensors: ${outputTensors.length}');
          for (var i = 0; i < outputTensors.length; i++) {
            final tensor = outputTensors[i];
            print('   Output[$i]:');
            print('     - Shape: ${tensor.shape}');
            print('     - Type: ${tensor.type}');
            print('     - Name: ${tensor.name}');
          }

          // Generate test data
          final candles = _generateBullishCandles(100);
          final feats = ModelUtils.featuresFromCandles(candles, 64, 15);
          final flat = ModelUtils.normalize2D(feats);

          // Reshape to [1, 64, 15]
          final input = _reshape(flat, [1, 64, 15]);

          // Try to run inference
          final outputShape = outputTensors[0].shape;
          final outputSize = outputShape.reduce((a, b) => a * b);

          print('\n🔍 RUNNING INFERENCE:');
          print('   Input shape: [1, 64, 15]');
          print('   Expected output size: $outputSize');

          final output = List.filled(outputSize, 0.0);

          interpreter.run(input, output);

          print('\n📤 RAW OUTPUT:');
          print('   ${output.map((x) => x.toStringAsFixed(6)).join(", ")}');

          // Analyze output
          print('\n🎯 ANALYSIS:');
          
          if (outputSize == 1) {
            print('   ⚠️  SCALAR OUTPUT (single value)');
            print('   → This is NOT a 3-class classifier');
            print('   → Need to use DirectionModelScalar adapter');
            
            final scalar = output[0];
            if (scalar >= 0 && scalar <= 1) {
              print('   → Scalar in [0,1] range: ${scalar.toStringAsFixed(4)}');
              print('   → Can be interpreted as signal strength');
            } else {
              print('   → Scalar outside [0,1]: ${scalar.toStringAsFixed(4)}');
              print('   → May need different interpretation');
            }
          } else if (outputSize == 3) {
            print('   ✅ 3-CLASS OUTPUT!');
            print('   → This model outputs [BUY, HOLD, SELL] probabilities');
            
            // Apply softmax
            final probs = _softmax(output);
            print('\n   After softmax:');
            print('     Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
            print('     Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
            print('     Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');
            
            // Check if uniform
            final isUniform = (probs[0] - 0.33).abs() < 0.02 &&
                              (probs[1] - 0.33).abs() < 0.02 &&
                              (probs[2] - 0.33).abs() < 0.02;
            
            if (isUniform) {
              print('   ⚠️  Output is UNIFORM (model may be broken)');
            } else {
              print('   ✅ Output is NON-UNIFORM (model works!)');
            }
          } else {
            print('   ⚠️  UNEXPECTED OUTPUT SIZE: $outputSize');
            print('   → Expected 1 (scalar) or 3 (3-class)');
          }

          interpreter.close();

          print('\n' + '=' * 70 + '\n');
        } catch (e, stack) {
          print('❌ ERROR testing $modelPath:');
          print('   $e');
          print(stack);
        }
      });
    }

    test('🏆 RECOMMENDATION', () {
      print('\n' + '=' * 70);
      print('🏆 FINAL RECOMMENDATION');
      print('=' * 70);
      print('\nBased on the tests above:');
      print('\n1. If ANY model has output shape [1, 3] and NON-UNIFORM:');
      print('   → Use that model directly in DirectionModel');
      print('   → Update model path in direction_model.dart');
      print('\n2. If ALL models have output shape [1, 1] (scalar):');
      print('   → Use DirectionModelScalar adapter');
      print('   → Wire it into AILocator/signal_engine');
      print('\n3. If ALL outputs are [1, 3] but UNIFORM (33/33/33):');
      print('   → Models are broken (normalization mismatch)');
      print('   → Use fallback technical rules temporarily');
      print('   → Retrain models with correct normalization');
      print('\n' + '=' * 70 + '\n');
    });
  });
}

List<Candle> _generateBullishCandles(int n) {
  final rnd = Random(42);
  final candles = <Candle>[];
  double price = 40000.0;

  for (int i = 0; i < n; i++) {
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

List<List<List<double>>> _reshape(List<double> flat, List<int> shape) {
  final result = <List<List<double>>>[];
  int idx = 0;

  for (int b = 0; b < shape[0]; b++) {
    final batch = <List<double>>[];
    for (int t = 0; t < shape[1]; t++) {
      final timestep = <double>[];
      for (int f = 0; f < shape[2]; f++) {
        timestep.add(flat[idx++]);
      }
      batch.add(timestep);
    }
    result.add(batch);
  }

  return result;
}

List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((x) => exp(x - maxLogit)).toList();
  final sum = exps.reduce((a, b) => a + b);
  return exps.map((x) => x / sum).toList();
}


