import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../entities.dart';
import '../indicators.dart';
import 'model_utils.dart';

/// VolatilityModel - Predict annualized volatility
/// Uses TFLite model if available, falls back to EWMA calculation
class VolatilityModel {
  tfl.Interpreter? _it;
  bool _tried = false;

  Future<void> _init() async {
    if (_tried) return;
    _tried = true;
    
    try {
      _it = await tfl.Interpreter.fromAsset(
        'assets/models/volatility_f32_builtin.tflite',
      );
      debugPrint('✅ VolatilityModel TFLite loaded');
    } catch (e) {
      _it = null;
      debugPrint('⚠️ VolatilityModel using fallback');
    }
  }

  /// Predict annualized volatility (0.65 = 65%)
  Future<double> predictVolatility(List<Candle> window) async {
    await _init();
    
    if (_it != null) {
      return _predictWithTFLite(window);
    } else {
      return _fallback(window);
    }
  }

  Future<double> _predictWithTFLite(List<Candle> window) async {
    try {
      // Build input using declared tensor shape
      final inTensor = _it!.getInputTensor(0);
      final inShape = inTensor.shape;
      final input = ModelUtils.buildInputTensor(window, inShape);
      try {
        _it!.resizeInputTensor(0, inShape);
        _it!.allocateTensors();
      } catch (_) {}
      
      final outTensor = _it!.getOutputTensor(0);
      final outShape = outTensor.shape;
      final output = ModelUtils.emptyOutput(outShape);
      
      // ignore: avoid_print
      print('🔍 Input shape: $inShape');
      // ignore: avoid_print
      print('🔍 Input sample: ${input[0][0]}');

      _it!.run(input, output);

      // Extract scalar and dequantize if needed
      var predictedVol = ModelUtils.extractScalar(output, outShape);
      try {
        final qp = outTensor.params;
        // If the tensor is quantized, scale will typically be != 0 and
        // zeroPoint may be non-zero. Applying dequantization is harmless
        // even if values are already float (scale ≈ 1, zero ≈ 0).
        final scale = qp.scale;
        final zero = qp.zeroPoint;
        if (scale != 0.0 && (scale != 1.0 || zero != 0)) {
          predictedVol = scale * (predictedVol - zero);
        }
      } catch (_) {}
      // Raw read for debugging
      // ignore: avoid_print
      print('VOL:raw=$predictedVol');
      
      // Handle invalid or non-positive vols (fallback to EWMA)
      if (!predictedVol.isFinite || predictedVol <= 0.0) {
        debugPrint('⚠️ VolatilityModel returned $predictedVol, using EWMA fallback');
        return _fallback(window);
      }
      
      // Decode based on training format
      // Dacă e în range 0-1, e fracție → convert la anual
      if (predictedVol <= 1.0) {
        // Likely daily vol → annualize
        predictedVol = predictedVol * sqrt(365);
      }
      // ignore: avoid_print
      print('VOL:ann=$predictedVol');
      
      debugPrint('✅ VolatilityModel TFLite: vol=${(predictedVol*100).toStringAsFixed(1)}%');
      
      // Clamp la valori realiste (1% - 300% anualizat)
      final clamped = predictedVol.clamp(0.01, 3.0);
      
      // Final safety: dacă e încă 0, use EWMA
      return clamped > 0.0 ? clamped : max(0.01, _fallback(window));
    } catch (e) {
      debugPrint('⚠️ VolatilityModel TFLite failed: $e');
      return _fallback(window);
    }
  }

  double _fallback(List<Candle> window) {
    final closes = window.map((c) => c.close).toList();
    
    // Use EWMA volatility cu lambda = 0.94 (standard RiskMetrics)
    final vol = ewmaVol(closes, lambda: 0.94);
    
    if (vol.isNaN) {
      // Fallback: calculate simple historical volatility
      if (closes.length < 2) return 0.20; // Default 20% annual
      
      final returns = <double>[];
      for (int i = 1; i < closes.length; i++) {
        returns.add(log(closes[i] / closes[i - 1]));
      }
      
      final mean = returns.reduce((a, b) => a + b) / returns.length;
      final variance = returns
          .map((r) => pow(r - mean, 2))
          .reduce((a, b) => a + b) / returns.length;
      
      final dailyVol = sqrt(variance);
      return dailyVol * sqrt(365); // Annualize
    }
    
    // Clamp la valori realiste
    return vol.clamp(0.01, 3.0);
  }

  void dispose() {
    _it?.close();
    _it = null;
  }
}

