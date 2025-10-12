import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import '../entities.dart';
import 'model_utils.dart';
import 'direction_model.dart';

/// TransformerDirectionModel
///
/// - TFLite-compatible Transformer encoder classifier
/// - Input: [1, 64, 15]
/// - Output: [BUY, HOLD, SELL] probabilities
/// - Softmax applied on logits if necessary
/// - Falls back to simple technical rules if model unavailable
class TransformerDirectionModel extends DirectionModel {
  tfl.Interpreter? _it;
  bool _tried = false;

  static const String _modelPath = 'assets/models/transformer_direction.tflite';

  @override
  Future<void> initialize() async {
    if (_tried) return;
    _tried = true;
    try {
      _it = await tfl.Interpreter.fromAsset(_modelPath);
      debugPrint('✅ TransformerDirectionModel loaded: $_modelPath');
    } catch (e) {
      _it = null;
      debugPrint('⚠️ TransformerDirectionModel not available: $e');
    }
  }

  @override
  Future<List<double>> predictProbs(List<Candle> candles) async {
    if (!_tried) {
      await initialize();
    }
    if (_it == null) {
      // Fallback to base DirectionModel behavior (technical rules)
      return super.predictProbs(candles);
    }

    try {
      // Model-declared shapes
      final inShape = _it!.getInputTensor(0).shape; // expect [1, 64, 15]
      if (inShape.length != 3 || inShape[0] != 1) {
        throw StateError('Unsupported input shape: $inShape');
      }

      final input = ModelUtils.buildInputTensor(candles, inShape);
      try {
        _it!.resizeInputTensor(0, inShape);
        _it!.allocateTensors();
      } catch (_) {}

      final outShape = _it!.getOutputTensor(0).shape; // expect [1, 3]
      final output = ModelUtils.emptyOutput(outShape);

      // Debug small trace
      // ignore: avoid_print
      print('🔍 Transformer input shape: $inShape');
      // ignore: avoid_print
      try {
        print('🔍 Transformer input sample: ${input[0][0]}');
      } catch (_) {}

      _it!.run(input, output);

      // Interpret output
      final totalOut = outShape.fold<int>(1, (a, b) => a * b);
      if (totalOut == 3) {
        // logits to probs
        List<double> logits;
        if (outShape.length == 1) {
          logits = (output as List).cast<double>();
        } else {
          logits = (output as List<List>).first.cast<double>();
        }
        final maxLogit = logits.reduce((a, b) => a > b ? a : b);
        final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
        final sum = exps.fold<double>(0.0, (a, b) => a + b);
        final probs = sum == 0.0
            ? const [1 / 3, 1 / 3, 1 / 3]
            : exps.map((x) => x / sum).toList();
        return probs.cast<double>();
      }

      if (totalOut == 1) {
        // Rare: scalar output → map via base model's mapping
        final scalar = ModelUtils.extractScalar(output, outShape);
        return super.predictProbs(candles); // will map via fallback rules
      }

      // Unknown output
      return super.predictProbs(candles);
    } catch (e, st) {
      debugPrint('❌ TransformerDirectionModel predict error: $e');
      debugPrint('Stack: $st');
      return super.predictProbs(candles);
    }
  }

  @override
  void dispose() {
    _it?.close();
    _it = null;
  }
}

/// ----------------------------
/// Training script (Python)
/// Saved under tool/train_transformer.py
/// ----------------------------
