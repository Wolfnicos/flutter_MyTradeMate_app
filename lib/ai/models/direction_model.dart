import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../entities.dart';
import 'model_utils.dart';

class DirectionModel {
  Interpreter? _interpreter;
  bool _initialized = false;

  // Use F32 for best accuracy (or switch to fp16 for performance)
  // Model path reserved for future use when re-enabling TFLite
  // ignore: unused_field
  static const String _modelPath = 'assets/models/direction_f32_builtin.tflite';

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _initialized = true;
      print('✅ DirectionModel initialized: $_modelPath');
    } catch (e) {
      print(
          '⚠️  DirectionModel failed to initialize, falling back to technical rules: $e');
      _interpreter = null; // explicit
      _initialized = true;
    }
  }

  Future<List<double>> predictProbs(List<Candle> candles) async {
    if (!_initialized) {
      await initialize();
    }

    // If model failed to load, use fallback
    if (_interpreter == null) {
      return _fallback(candles);
    }

    try {
      // Build input based on model-declared shape (handles [1,15,64] vs [1,64,15])
      final inTensor = _interpreter!.getInputTensor(0);
      final inShape = inTensor.shape;
      final input = ModelUtils.buildInputTensor(candles, inShape);
      final outTensor = _interpreter!.getOutputTensor(0);
      final outShape = outTensor.shape;

      // Allocate output buffer; use ints for quantized tensors
      dynamic output;
      // Quantized tensor types in tflite_flutter are typically reported as kTfLiteUInt8/kTfLiteInt8
      final isQuantized = outTensor.type.toString().contains('Int') ||
          outTensor.type.toString().contains('UInt');
      if (isQuantized) {
        if (outShape.length == 1) {
          output = List.filled(outShape[0], 0);
        } else if (outShape.length == 2) {
          output =
              List.generate(outShape[0], (_) => List.filled(outShape[1], 0));
        } else if (outShape.length == 3) {
          output = List.generate(
              outShape[0],
              (_) => List.generate(
                  outShape[1], (_) => List.filled(outShape[2], 0)));
        } else {
          output = ModelUtils.emptyOutput(outShape);
        }
      } else {
        output = ModelUtils.emptyOutput(outShape);
      }

      // ignore: avoid_print
      print('🔍 DirectionModel input shape: $inShape');
      // ignore: avoid_print
      try {
        print('🔍 DirectionModel input sample: ${input[0][0]}');
      } catch (_) {}

      _interpreter!.run(input, output);

      // Decide how to interpret output
      final totalOut = outShape.fold<int>(1, (a, b) => a * b);

      if (totalOut == 1) {
        // Scalar → map to [buy, hold, sell]
        double scalar;
        if (output is List<int>) {
          // Dequantize scalar
          final qp = outTensor.params;
          final scale = qp.scale;
          final zero = qp.zeroPoint;
          scalar = scale * (output[0] - zero);
        } else if (output is List<List<int>>) {
          final qp = outTensor.params;
          final scale = qp.scale;
          final zero = qp.zeroPoint;
          scalar = scale * (output[0][0] - zero);
        } else {
          scalar = ModelUtils.extractScalar(output, outShape);
        }
        // ignore: avoid_print
        print('🔍 DirectionModel raw scalar: ${scalar.toStringAsFixed(6)}');
        final probs = _scalarToProbs(scalar);
        // ignore: avoid_print
        print(
            '   probs: [${(probs[0] * 100).toStringAsFixed(0)} ${(probs[1] * 100).toStringAsFixed(0)} ${(probs[2] * 100).toStringAsFixed(0)}]%');
        return probs;
      }

      if (totalOut == 3) {
        // 3-class: assume row vector or [1,3]
        List<double> logits;
        if (output is List<int>) {
          final qp = outTensor.params;
          final scale = qp.scale;
          final zero = qp.zeroPoint;
          logits = output.map((q) => scale * (q - zero)).toList();
        } else if (output is List<List<int>>) {
          final qp = outTensor.params;
          final scale = qp.scale;
          final zero = qp.zeroPoint;
          logits = output.first
              .map((q) => scale * (q - zero))
              .cast<double>()
              .toList();
        } else if (outShape.length == 1) {
          logits = (output as List).cast<double>();
        } else {
          logits = (output as List<List>).first.cast<double>();
        }
        // Softmax
        final maxLogit = logits.reduce((a, b) => a > b ? a : b);
        final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
        final sum = exps.fold<double>(0.0, (a, b) => a + b);
        final probs = sum == 0.0
            ? const [1 / 3, 1 / 3, 1 / 3]
            : exps.map((x) => x / sum).toList();
        return probs.cast<double>();
      }

      // Unknown shape → fallback
      return _fallback(candles);
    } catch (e) {
      print('⚠️  DirectionModel inference error: $e');
      return _fallback(candles);
    }
  }

  /// Convert scalar [0, 1] to [buy, hold, sell] probabilities
  ///
  /// Interpretation:
  /// - 0.0 - 0.35: Strong SELL
  /// - 0.35 - 0.45: Weak SELL / HOLD
  /// - 0.45 - 0.55: HOLD (neutral zone)
  /// - 0.55 - 0.65: Weak BUY / HOLD
  /// - 0.65 - 1.0: Strong BUY
  List<double> _scalarToProbs(double scalar) {
    // Clamp to valid range
    scalar = scalar.clamp(0.0, 1.0);

    double buy, hold, sell;

    if (scalar < 0.35) {
      // Strong SELL zone
      final sellStrength = (0.35 - scalar) / 0.35; // [0, 1]
      sell = 0.35 + sellStrength * 0.55; // [0.35, 0.90]
      hold = 0.25 - sellStrength * 0.15; // [0.10, 0.25]
      buy = 1.0 - sell - hold;
    } else if (scalar < 0.45) {
      // Weak SELL to HOLD transition
      final position = (scalar - 0.35) / 0.1; // [0, 1]
      sell = 0.35 - position * 0.15; // [0.35, 0.20]
      hold = 0.25 + position * 0.25; // [0.25, 0.50]
      buy = 1.0 - sell - hold;
    } else if (scalar < 0.55) {
      // HOLD zone (centered around 0.5)
      final centerDist = (scalar - 0.5).abs();
      hold = 0.50 + (0.05 - centerDist) * 2; // Peak at 0.5
      hold = hold.clamp(0.40, 0.60);
      final remainder = 1.0 - hold;

      if (scalar < 0.5) {
        sell = remainder * 0.6;
        buy = remainder * 0.4;
      } else {
        buy = remainder * 0.6;
        sell = remainder * 0.4;
      }
    } else if (scalar < 0.65) {
      // Weak BUY to HOLD transition
      final position = (scalar - 0.55) / 0.1; // [0, 1]
      buy = 0.35 - position * 0.15; // Start building BUY
      hold = 0.50 - position * 0.25; // [0.50, 0.25]
      sell = 1.0 - buy - hold;

      // Flip: we want buy to increase
      final temp = buy;
      buy = sell;
      sell = temp;
    } else {
      // Strong BUY zone
      final buyStrength = (scalar - 0.65) / 0.35; // [0, 1]
      buy = 0.35 + buyStrength * 0.55; // [0.35, 0.90]
      hold = 0.25 - buyStrength * 0.15; // [0.25, 0.10]
      sell = 1.0 - buy - hold;
    }

    // Normalize to ensure sum = 1.0
    final sum = buy + hold + sell;
    return [buy / sum, hold / sum, sell / sum];
  }

  // No longer needed: input reshaping handled via ModelUtils.buildInputTensor

  /// Fallback using technical indicators
  List<double> _fallback(List<Candle> candles) {
    if (candles.length < 26) {
      return [0.30, 0.40, 0.30]; // Neutral with slight HOLD bias
    }

    final recent = candles.sublist(candles.length - 26);
    final closes = recent.map((c) => c.close).toList();

    // EMA crossover
    final ema12 = _ema(closes, 12);
    final ema26 = _ema(closes, 26);
    final emaDiff = (ema12 - ema26) / ema26;

    // RSI
    final rsi = _rsi(recent, 14);

    // Volume
    final avgVol =
        recent.map((c) => c.volume).reduce((a, b) => a + b) / recent.length;
    final recentVol = recent
            .sublist(recent.length - 3)
            .map((c) => c.volume)
            .reduce((a, b) => a + b) /
        3;
    final volumeRatio = recentVol / avgVol;

    // Price momentum
    final priceChange = (closes.last - closes.first) / closes.first;

    // Bullish signals
    if (emaDiff > 0.002 && rsi > 50 && rsi < 75 && volumeRatio > 0.9) {
      final strength = ((rsi - 50) / 25).clamp(0.0, 1.0);
      final volBoost = ((volumeRatio - 0.9) / 1.0).clamp(0.0, 0.2);

      final buy = 0.40 + strength * 0.30 + volBoost;
      final hold = 0.35 - strength * 0.15;
      final sell = 1.0 - buy - hold;

      return [buy, hold, sell];
    }

    // Bearish signals
    if (emaDiff < -0.002 && rsi > 25 && rsi < 50 && volumeRatio > 0.9) {
      final strength = ((50 - rsi) / 25).clamp(0.0, 1.0);
      final volBoost = ((volumeRatio - 0.9) / 1.0).clamp(0.0, 0.2);

      final sell = 0.40 + strength * 0.30 + volBoost;
      final hold = 0.35 - strength * 0.15;
      final buy = 1.0 - sell - hold;

      return [buy, hold, sell];
    }

    // Strong momentum override
    if (priceChange.abs() > 0.03) {
      if (priceChange > 0 && rsi < 70) {
        return [0.55, 0.30, 0.15];
      } else if (priceChange < 0 && rsi > 30) {
        return [0.15, 0.30, 0.55];
      }
    }

    // Neutral/HOLD (slightly favor based on RSI)
    if (rsi > 55) {
      return [0.35, 0.40, 0.25];
    } else if (rsi < 45) {
      return [0.25, 0.40, 0.35];
    }

    return [0.30, 0.40, 0.30];
  }

  double _ema(List<double> prices, int period) {
    if (prices.isEmpty) return 0.0;
    if (prices.length < period) return prices.last;

    final alpha = 2.0 / (period + 1);
    double ema = prices[0];

    for (int i = 1; i < prices.length; i++) {
      ema = prices[i] * alpha + ema * (1 - alpha);
    }

    return ema;
  }

  double _rsi(List<Candle> candles, int period) {
    if (candles.length < period + 1) return 50.0;

    double gains = 0;
    double losses = 0;

    for (int i = candles.length - period; i < candles.length; i++) {
      if (i == 0) continue;
      final change = candles[i].close - candles[i - 1].close;
      if (change > 0) {
        gains += change;
      } else {
        losses += -change;
      }
    }

    if (losses == 0) return 100.0;

    final avgGain = gains / period;
    final avgLoss = losses / period;
    final rs = avgGain / avgLoss;

    return 100 - (100 / (1 + rs));
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}
