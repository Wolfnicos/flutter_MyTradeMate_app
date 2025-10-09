// lib/ai/models/direction_model_scalar.dart
// Adaptare pentru model cu output scalar [0, 1] în loc de 3 clase

import 'package:tflite_flutter/tflite_flutter.dart';
import '../entities.dart';
import 'model_utils.dart';

class DirectionModelScalar {
  Interpreter? _interpreter;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('🔧 [DirectionScalar] Loading TFLite model...');
      // Try preferred path; fall back to known asset names if missing
      try {
        _interpreter = await Interpreter.fromAsset('assets/models/direction_model.tflite');
      } catch (_) {
        try {
          _interpreter = await Interpreter.fromAsset('assets/models/direction_f32_builtin.tflite');
        } catch (_) {
          _interpreter = await Interpreter.fromAsset('assets/models/direction_fp16_builtin.tflite');
        }
      }

      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('📊 MODEL INFO:');
      print('   Input[0]: shape=${inputTensors[0].shape}');
      print('   Output[0]: shape=${outputTensors[0].shape}');

      _initialized = true;
      print('✅ [DirectionScalar] Initialized\n');
    } catch (e, stack) {
      print('❌ [DirectionScalar] Failed: $e');
      print(stack);
      rethrow;
    }
  }

  Future<List<double>> predictProbs(List<Candle> candles) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final feats = ModelUtils.featuresFromCandles(candles, 64, 15);
      final flat = ModelUtils.normalize2D(feats);

      // Reshape to [1, 64, 15]
      final input = _reshapeFlat(flat, [1, 64, 15]);

      // Output is [1, 1] - a single scalar (allow flat list of length 1)
      final output = List.filled(1, 0.0);

      print('🔍 Running inference...');
      _interpreter!.run(input, output);

      final scalar = output[0];
      print('   Raw scalar output: ${scalar.toStringAsFixed(6)}');

      final probs = _scalarToProbs(scalar);

      print('   Interpreted as:');
      print('     Buy:  ${(probs[0] * 100).toStringAsFixed(2)}%');
      print('     Hold: ${(probs[1] * 100).toStringAsFixed(2)}%');
      print('     Sell: ${(probs[2] * 100).toStringAsFixed(2)}%');

      return probs;
    } catch (e, stack) {
      print('❌ [DirectionScalar] Error: $e');
      print(stack);

      // Fallback to technical rules
      return _fallback(candles);
    }
  }

  /// Convert scalar [0, 1] to [buy, hold, sell] probabilities
  List<double> _scalarToProbs(double scalar) {
    // Clamp to [0, 1]
    scalar = scalar.clamp(0.0, 1.0);

    // Strategy 1: Linear mapping with dead zone
    // 0.0 - 0.3 → Strong SELL
    // 0.3 - 0.4 → Weak SELL
    // 0.4 - 0.6 → HOLD
    // 0.6 - 0.7 → Weak BUY
    // 0.7 - 1.0 → Strong BUY

    double buy, hold, sell;

    if (scalar < 0.3) {
      // Strong SELL zone
      sell = 0.4 + (0.3 - scalar) / 0.3 * 0.5; // [0.4, 0.9]
      hold = 0.1 + (scalar / 0.3) * 0.3; // [0.1, 0.4]
      buy = 1.0 - sell - hold;
    } else if (scalar < 0.4) {
      // Weak SELL zone
      sell = 0.4 + (0.4 - scalar) / 0.1 * 0.2; // [0.4, 0.6]
      hold = 0.3 + (scalar - 0.3) / 0.1 * 0.1; // [0.3, 0.4]
      buy = 1.0 - sell - hold;
    } else if (scalar < 0.6) {
      // HOLD zone (centered)
      hold = 0.4 + (1.0 - (scalar - 0.5).abs() / 0.1) * 0.2; // [0.4, 0.6]
      final remainder = 1.0 - hold;
      sell = remainder * (0.6 - scalar) / 0.2;
      buy = remainder * (scalar - 0.4) / 0.2;
    } else if (scalar < 0.7) {
      // Weak BUY zone
      buy = 0.4 + (scalar - 0.6) / 0.1 * 0.2; // [0.4, 0.6]
      hold = 0.3 + (0.7 - scalar) / 0.1 * 0.1; // [0.3, 0.4]
      sell = 1.0 - buy - hold;
    } else {
      // Strong BUY zone
      buy = 0.4 + (scalar - 0.7) / 0.3 * 0.5; // [0.4, 0.9]
      hold = 0.1 + (1.0 - scalar) / 0.3 * 0.3; // [0.1, 0.4]
      sell = 1.0 - buy - hold;
    }

    // Normalize to sum to 1.0
    final sum = buy + hold + sell;
    return [buy / sum, hold / sum, sell / sum];
  }

  dynamic _reshapeFlat(List<double> flat, List<int> targetShape) {
    // [1, 64, 15]
    final result = <List<List<double>>>[];
    int idx = 0;

    for (int b = 0; b < targetShape[0]; b++) {
      final batch = <List<double>>[];
      for (int t = 0; t < targetShape[1]; t++) {
        final timestep = <double>[];
        for (int f = 0; f < targetShape[2]; f++) {
          timestep.add(flat[idx++]);
        }
        batch.add(timestep);
      }
      result.add(batch);
    }

    return result;
  }

  List<double> _fallback(List<Candle> candles) {
    print('🔄 Using fallback (technical rules)...');

    if (candles.length < 26) {
      return const [0.33, 0.34, 0.33];
    }

    final recent = candles.sublist(candles.length - 26);

    // Simple EMA crossover + RSI
    final closes = recent.map((c) => c.close).toList();
    final ema12 = _ema(closes, 12);
    final ema26 = _ema(closes, 26);
    final rsi = _rsi(recent, 14);

    // Bullish: EMA12 > EMA26 && 50 < RSI < 70
    if (ema12 > ema26 && rsi > 50 && rsi < 70) {
      return const [0.6, 0.3, 0.1];
    }

    // Bearish: EMA12 < EMA26 && 30 < RSI < 50
    if (ema12 < ema26 && rsi > 30 && rsi < 50) {
      return const [0.1, 0.3, 0.6];
    }

    // Neutral
    return const [0.33, 0.34, 0.33];
  }

  double _ema(List<double> prices, int period) {
    if (prices.isEmpty) return 0.0;

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
    final rs = (gains / period) / (losses / period);
    return 100 - (100 / (1 + rs));
  }

  void dispose() {
    if (_initialized) {
      _interpreter?.close();
      _interpreter = null;
      _initialized = false;
    }
  }
}


