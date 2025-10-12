import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../entities.dart';
import '../indicators.dart';
import 'model_utils.dart';

/// ReturnModel - Predict expected return pentru următoarea perioadă
/// Uses TFLite model if available, falls back to momentum-based estimation
class ReturnModel {
  tfl.Interpreter? _it;
  bool _tried = false;

  Future<void> _init() async {
    if (_tried) return;
    _tried = true;

    try {
      _it = await tfl.Interpreter.fromAsset(
        'assets/models/return_f32_builtin.tflite',
      );
      debugPrint('✅ ReturnModel TFLite loaded');
    } catch (e) {
      _it = null;
      debugPrint('⚠️ ReturnModel using fallback');
    }
  }

  /// Predict expected return (fracție, ex: 0.012 = +1.2%)
  Future<double> predictReturn(List<Candle> window) async {
    await _init();

    if (_it != null) {
      return _predictWithTFLite(window);
    } else {
      return _fallback(window);
    }
  }

  Future<double> _predictWithTFLite(List<Candle> window) async {
    try {
      final inShape = _it!.getInputTensor(0).shape;
      final input = ModelUtils.buildInputTensor(window, inShape);
      try {
        _it!.resizeInputTensor(0, inShape);
        _it!.allocateTensors();
      } catch (_) {}

      final outShape = _it!.getOutputTensor(0).shape;
      final output = ModelUtils.emptyOutput(outShape);

      _it!.run(input, output);

      var predictedReturn = ModelUtils.extractScalar(output, outShape);
      // Raw read for debugging
      // ignore: avoid_print
      print('RET:raw=$predictedReturn');

      // Decode based on training format
      // Dacă e log-return: convert înapoi
      if (predictedReturn.abs() < 0.5) {
        // Likely already a percentage/fraction → use as-is
        // No conversion needed
      } else if (predictedReturn.abs() > 10) {
        // Likely basis points (bp) → convert
        predictedReturn = predictedReturn / 10000.0;
        debugPrint('📊 Converted basis points: ${predictedReturn * 100}%');
      }
      // ignore: avoid_print
      print('RET:pct=$predictedReturn');

      debugPrint(
          '✅ ReturnModel TFLite: return=${(predictedReturn * 100).toStringAsFixed(2)}%');

      // Clamp la valori realiste (±5%)
      return predictedReturn.clamp(-0.05, 0.05);
    } catch (e) {
      debugPrint('⚠️ ReturnModel TFLite failed: $e');
      return _fallback(window);
    }
  }

  double _fallback(List<Candle> window) {
    final closes = window.map((c) => c.close).toList();

    // Calculate momentum indicators
    final ema12 = ema(closes, 12);
    final ema26 = ema(closes, 26);
    final rsi14 = rsi(closes, period: 14);

    // Calculate recent returns
    final recentReturns = <double>[];
    for (int i = max(0, closes.length - 10); i < closes.length - 1; i++) {
      recentReturns.add(log(closes[i + 1] / closes[i]));
    }

    final avgRecentReturn = recentReturns.isEmpty
        ? 0.0
        : recentReturns.reduce((a, b) => a + b) / recentReturns.length;

    // Estimate based on momentum
    double estimatedReturn = avgRecentReturn * 0.5; // Dampened momentum

    // Adjust based on EMA cross
    if (ema12 > ema26) {
      estimatedReturn += 0.002; // +0.2% bullish bias
    } else if (ema12 < ema26) {
      estimatedReturn -= 0.002; // -0.2% bearish bias
    }

    // Adjust based on RSI extremes
    if (rsi14 < 30) {
      estimatedReturn += 0.003; // Oversold → likely bounce
    } else if (rsi14 > 70) {
      estimatedReturn -= 0.003; // Overbought → likely pullback
    }

    // Clamp la valori realiste (±5%)
    return estimatedReturn.clamp(-0.05, 0.05);
  }

  void dispose() {
    _it?.close();
    _it = null;
  }
}
