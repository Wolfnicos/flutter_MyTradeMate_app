import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter/foundation.dart';
import '../entities.dart';
import '../indicators.dart';
import 'model_utils.dart';
import 'dart:math';

/// DirectionModel - Predict BUY/HOLD/SELL probabilities
/// Uses TFLite model if available, falls back to rule-based
class DirectionModel {
  tfl.Interpreter? _it;
  bool _tried = false;

  /// Lazy load TFLite model (only once)
  Future<void> _init() async {
    if (_tried) return;
    _tried = true;
    
    try {
      _it = await tfl.Interpreter.fromAsset(
        'assets/models/direction_f32_builtin.tflite',
      );
      debugPrint('✅ DirectionModel TFLite loaded');
    } catch (e) {
      _it = null;
      debugPrint('⚠️ DirectionModel using fallback (TFLite not available)');
    }
  }

  /// Predict probabilities [pBuy, pHold, pSell]
  Future<List<double>> predictProbs(List<Candle> window) async {
    await _init();
    
    if (_it != null) {
      return _predictWithTFLite(window);
    } else {
      return _fallback(window);
    }
  }

  /// TFLite prediction with dynamic shape handling
  Future<List<double>> _predictWithTFLite(List<Candle> window) async {
    try {
      // Read actual input shape from model
      final inTensor = _it!.getInputTensor(0);
      final inputShape = inTensor.shape; // e.g. [1, 64, 6, 1] for CONV_2D
      
      debugPrint('📐 DirectionModel input shape: $inputShape');
      
      // Build input tensor based on shape
      final input = ModelUtils.buildInputTensor(window, inputShape);
      
      // Read output shape
      final outTensor = _it!.getOutputTensor(0);
      final outShape = outTensor.shape; // e.g. [1, 3]
      
      // Create empty output
      final output = ModelUtils.emptyOutput(outShape);
      
      // Run inference
      _it!.run(input, output);
      
      // Extract probabilities
      var probs = ModelUtils.extractProbs(output, outShape, 3);
      
      // Apply softmax if output are logits (not already probabilities)
      // Check: dacă sum e departe de 1.0, apply softmax
      final sum = probs.fold(0.0, (a, b) => a + b);
      if ((sum - 1.0).abs() > 0.1 || probs.any((p) => p < 0 || p > 1)) {
        probs = _softmax(probs);
        debugPrint('📊 Applied softmax to logits');
      }
      
      debugPrint('✅ DirectionModel TFLite: probs=${probs.map((p) => (p*100).toStringAsFixed(0)).join(",")}');
      
      return probs;
    } catch (e, st) {
      debugPrint('⚠️ DirectionModel TFLite failed: $e');
      if (kDebugMode) debugPrint('Stack: $st');
      return _fallback(window);
    }
  }

  /// Rule-based fallback usando indicatori
  List<double> _fallback(List<Candle> window) {
    final closes = window.map((c) => c.close).toList();
    
    // Calculate indicators
    final rsi14 = rsi(closes, period: 14);
    final ema12 = ema(closes, 12);
    final ema26 = ema(closes, 26);
    final macdData = macdValues(closes);
    final volume = relativeVolume(window, period: 20);
    
    double pBuy = 0.33;
    double pHold = 0.34;
    double pSell = 0.33;
    
    // Rule 1: EMA Cross + RSI
    if (ema12 > ema26 && rsi14 < 70 && rsi14 > 50) {
      // Bullish: fast > slow, not overbought
      pBuy = 0.55;
      pHold = 0.30;
      pSell = 0.15;
    } else if (ema12 < ema26 && rsi14 > 30 && rsi14 < 50) {
      // Bearish: fast < slow, not oversold
      pSell = 0.55;
      pHold = 0.30;
      pBuy = 0.15;
    }
    
    // Rule 2: Strong RSI signals
    if (rsi14 < 30 && volume > 1.2) {
      // Oversold with high volume → likely bounce
      pBuy = max(pBuy, 0.60);
      pSell = min(pSell, 0.15);
    } else if (rsi14 > 70 && volume > 1.2) {
      // Overbought with high volume → likely correction
      pSell = max(pSell, 0.60);
      pBuy = min(pBuy, 0.15);
    }
    
    // Rule 3: MACD confirmation
    if (macdData.macd > 0 && macdData.histogram > 0) {
      // Bullish MACD
      pBuy *= 1.15;
    } else if (macdData.macd < 0 && macdData.histogram < 0) {
      // Bearish MACD
      pSell *= 1.15;
    }
    
    // Normalize to sum = 1
    final sum = pBuy + pHold + pSell;
    return [pBuy / sum, pHold / sum, pSell / sum];
  }

  /// Softmax function (convert logits → probabilities)
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits.map((v) => exp(v - maxLogit)).toList();
    final sumExp = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  /// Dispose interpreter
  void dispose() {
    _it?.close();
    _it = null;
  }
}

