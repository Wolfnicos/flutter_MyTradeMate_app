import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import '../entities.dart';
import 'model_utils.dart';

/// Debug-friendly Direction model with aggressive logging to diagnose
/// input shapes, normalization, and output behavior (uniform probs, zeros).
class DirectionModelDebug {
  tfl.Interpreter? _interpreter;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔧 [DirectionModel] Loading TFLite model...');
      // Use an existing asset from this project
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/direction_f32_builtin.tflite');

      // Log model details (best-effort)
      try {
        final in0 = _interpreter!.getInputTensor(0);
        final out0 = _interpreter!.getOutputTensor(0);
        print('📊 MODEL INFO:');
        print('   Input[0]: shape=${in0.shape}, type=${in0.type}, name=${in0.name}');
        print('   Output[0]: shape=${out0.shape}, type=${out0.type}, name=${out0.name}');
      } catch (e) {
        print('⚠️  Could not enumerate tensors: $e');
      }

      _initialized = true;
      print('✅ [DirectionModel] Initialized successfully\n');
    } catch (e, stack) {
      print('❌ [DirectionModel] Failed to initialize: $e');
      print(stack);
      rethrow;
    }
  }

  Future<List<double>> predictProbs(List<Candle> candles) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Extract features
      print('🔍 [DirectionModel] Extracting features...');
      final feats = ModelUtils.featuresFromCandles(candles, 64, 15);
      print('   Window size: ${feats.length}');
      print('   Features per timestep: ${feats[0].length}');

      // Log feature statistics BEFORE normalization
      print('\n📊 FEATURES BEFORE NORMALIZATION:');
      for (int featIdx = 0; featIdx < min(5, feats[0].length); featIdx++) {
        final values = feats.map((row) => row[featIdx]).toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final std = sqrt(values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / values.length);
        final minVal = values.reduce((a, b) => a < b ? a : b);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        print('   Feature $featIdx: mean=${mean.toStringAsFixed(6)}, std=${std.toStringAsFixed(6)}, '
              'range=[${minVal.toStringAsFixed(6)}, ${maxVal.toStringAsFixed(6)}]');
      }
      print('   ... (${feats[0].length - 5} more features)');

      // Normalize
      final flat = ModelUtils.normalize2D(feats);

      // Log feature statistics AFTER normalization
      print('\n📊 FEATURES AFTER NORMALIZATION:');
      for (int featIdx = 0; featIdx < min(5, feats[0].length); featIdx++) {
        final values = <double>[];
        for (int t = 0; t < feats.length; t++) {
          values.add(flat[t * feats[0].length + featIdx]);
        }
        final mean = values.reduce((a, b) => a + b) / values.length;
        final std = sqrt(values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / values.length);
        final minVal = values.reduce((a, b) => a < b ? a : b);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        print('   Feature $featIdx: mean=${mean.toStringAsFixed(6)}, std=${std.toStringAsFixed(6)}, '
              'range=[${minVal.toStringAsFixed(6)}, ${maxVal.toStringAsFixed(6)}]');
      }

      // Check for NaN/Inf
      final hasNaN = flat.any((x) => x.isNaN);
      final hasInf = flat.any((x) => x.isInfinite);
      if (hasNaN) print('⚠️  WARNING: Features contain NaN!');
      if (hasInf) print('⚠️  WARNING: Features contain Infinity!');

      // Try multiple shapes
      print('\n🔄 TRYING DIFFERENT INPUT SHAPES:');
      final input1 = _reshapeFlat(flat, [1, 64, 15]);
      final input2 = _reshapeFlat(flat, [1, 64, 15, 1]);

      // Use a generic output buffer [1,3]
      List<List<double>> output = [List.filled(3, 0.0)];

      print('   Attempt 1: Shape [1, 64, 15]');
      try {
        _interpreter!.run(input1, output);
        print('   ✅ Success with [1, 64, 15]');
        final raw = _flatten(output);
        print('\n📤 RAW OUTPUT (logits): ${raw.map((x) => x.toStringAsFixed(6)).toList()}');
        final probs = _softmax(raw);
        _printProbs(probs);
        return probs;
      } catch (e) {
        print('   ❌ Failed: $e');
        print('   Attempt 2: Shape [1, 64, 15, 1]');
        try {
          output = [List.filled(3, 0.0)];
          _interpreter!.run(input2, output);
          print('   ✅ Success with [1, 64, 15, 1]');
          final raw = _flatten(output);
          print('\n📤 RAW OUTPUT (logits): ${raw.map((x) => x.toStringAsFixed(6)).toList()}');
          final probs = _softmax(raw);
          _printProbs(probs);
          return probs;
        } catch (e2) {
          print('   ❌ Failed: $e2');
          throw Exception('Both input shapes failed');
        }
      }
    } catch (e, stack) {
      print('\n❌ [DirectionModel] Error during prediction: $e');
      print(stack);
      print('\n🔄 Using fallback...');
      return const [0.33, 0.34, 0.33];
    }
  }

  dynamic _reshapeFlat(List<double> flat, List<int> targetShape) {
    final expectedSize = targetShape.reduce((a, b) => a * b);
    List<double> data = flat;
    if (data.length != expectedSize) {
      print('   ⚠️  Size mismatch: flat has ${data.length}, need $expectedSize');
      if (data.length < expectedSize) {
        data = [...data, ...List.filled(expectedSize - data.length, 0.0)];
      } else {
        data = data.sublist(0, expectedSize);
      }
    }

    if (targetShape.length == 3) {
      // [batch, timesteps, features]
      final result = <List<List<double>>>[];
      int idx = 0;
      for (int b = 0; b < targetShape[0]; b++) {
        final batch = <List<double>>[];
        for (int t = 0; t < targetShape[1]; t++) {
          final timestep = <double>[];
          for (int f = 0; f < targetShape[2]; f++) {
            timestep.add(data[idx++]);
          }
          batch.add(timestep);
        }
        result.add(batch);
      }
      return result;
    } else if (targetShape.length == 4) {
      // [batch, timesteps, features, channels]
      final result = <List<List<List<double>>>>[];
      int idx = 0;
      for (int b = 0; b < targetShape[0]; b++) {
        final batch = <List<List<double>>>[];
        for (int t = 0; t < targetShape[1]; t++) {
          final timestep = <List<double>>[];
          for (int f = 0; f < targetShape[2]; f++) {
            final channel = <double>[];
            for (int c = 0; c < targetShape[3]; c++) {
              channel.add(data[idx++]);
            }
            timestep.add(channel);
          }
          batch.add(timestep);
        }
        result.add(batch);
      }
      return result;
    }
    throw Exception('Unsupported shape: $targetShape');
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return const [1/3, 1/3, 1/3];
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((x) => exp(x - maxLogit)).toList();
    final sum = exps.fold<double>(0.0, (a, b) => a + b);
    if (sum == 0) return const [1/3, 1/3, 1/3];
    return exps.map((x) => x / sum).toList();
  }

  void _printProbs(List<double> probs) {
    print('\n📤 AFTER SOFTMAX (probabilities):');
    print('   Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
    print('   Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
    print('   Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');
    if ((probs[0] - 0.33).abs() < 0.02 &&
        (probs[1] - 0.33).abs() < 0.02 &&
        (probs[2] - 0.33).abs() < 0.02) {
      print('\n🚨 UNIFORM DISTRIBUTION DETECTED!');
      print('   Model is producing uninformative outputs.');
    }
  }

  List<double> _flatten(dynamic tensor) {
    final out = <double>[];
    void walk(dynamic node) {
      if (node is List) {
        for (final e in node) {
          walk(e);
        }
      } else if (node is num) {
        out.add(node.toDouble());
      }
    }
    walk(tensor);
    return out;
  }

  void dispose() {
    if (_initialized) {
      _interpreter?.close();
      _interpreter = null;
      _initialized = false;
    }
  }
}


