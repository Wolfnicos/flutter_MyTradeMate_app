import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import '../entities.dart';
import 'model_utils.dart';

class TransformerPriceModel {
  tfl.Interpreter? _interpreter;
  bool _tried = false;

  Future<void> initialize() async {
    if (_tried) return;
    _tried = true;
    try {
      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/models/price_transformer.tflite',
      );
      debugPrint('✅ TransformerPriceModel loaded');
    } catch (e) {
      _interpreter = null;
      debugPrint('⚠️ TransformerPriceModel not available: $e');
    }
  }

  Future<PricePrediction?> predict(List<Candle> candles) async {
    if (_interpreter == null) {
      await initialize();
      if (_interpreter == null) return null;
    }

    try {
      // Read shapes from model to avoid mismatches
      final inTensor = _interpreter!.getInputTensor(0);
      final inShape = inTensor.shape; // e.g. [1, 64, 15]

      // Build [1, T, F] input
      final input = _buildTransformerInput(candles, inShape);

      // Ensure tensors are allocated for expected shape
      try {
        _interpreter!.resizeInputTensor(0, inShape);
        _interpreter!.allocateTensors();
      } catch (_) {}

      // Prepare output buffer based on model output shape
      final outTensor = _interpreter!.getOutputTensor(0);
      final outShape = outTensor.shape; // e.g. [1, H, 4]
      final output = _emptyOutput3D(outShape);

      _interpreter!.run(input, output);

      return PricePrediction.fromTensor(output);
    } catch (e, st) {
      debugPrint('❌ TransformerPriceModel predict error: $e');
      debugPrint('Stack: $st');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  List<List<List<double>>> _buildTransformerInput(
    List<Candle> candles,
    List<int> inShape,
  ) {
    // Expect [1, seq_len, features]
    final dims = inShape.length;
    if (dims != 3 || inShape[0] != 1) {
      throw ArgumentError('Unsupported transformer input shape: $inShape');
    }
    final seqLen = inShape[1];
    final nFeatures = inShape[2];

    if (candles.length < seqLen) {
      throw ArgumentError('Need at least $seqLen candles');
    }

    // Build features [seqLen, nFeatures]
    final feats = ModelUtils.featuresFromCandles(candles, seqLen, nFeatures);
    final flat = ModelUtils.normalize2D(feats);

    // Reshape to [1, T, F]
    return [
      List.generate(seqLen, (t) =>
          List.generate(nFeatures, (f) => flat[t * nFeatures + f])),
    ];
  }

  List<List<List<double>>> _emptyOutput3D(List<int> shape) {
    if (shape.length != 3) {
      throw ArgumentError('Unsupported transformer output shape: $shape');
    }
    return List.generate(
      shape[0],
      (_) => List.generate(
        shape[1],
        (_) => List.filled(shape[2], 0.0),
      ),
    );
  }
}

class PricePrediction {
  final List<List<double>> horizon; // [H, 4] = [direction, return, vol, confidence]

  PricePrediction(this.horizon);

  factory PricePrediction.fromTensor(List<List<List<double>>> tensor) {
    // tensor: [1, H, 4]
    final h = tensor[0];
    return PricePrediction(h.map((e) => e.cast<double>()).toList());
  }

  double get direction => horizon.isEmpty ? 0.0 : horizon.last[0];
  double get expectedReturn => horizon.isEmpty ? 0.0 : horizon.last[1];
  double get volatility => horizon.isEmpty ? 0.0 : horizon.last[2];
  double get confidence => horizon.isEmpty ? 0.0 : horizon.last[3];
}


