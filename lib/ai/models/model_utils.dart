import 'package:flutter/foundation.dart';
import 'dart:math';
import '../entities.dart';

/// ModelUtils - Utility functions pentru TFLite models
/// Handles dynamic tensor shapes (2D/3D/4D) pentru CONV_2D compatibility
class ModelUtils {
  /// Minimum window size pentru predicții
  static const int kMinWindow = 64;

  /// Extract exact 15 features per timestep (match training!)
  /// Returns [seqLen, 15] matrix
  /// 
  /// Features (15 total):
  /// 0-2: returns (1, 5, 15 periods)
  /// 3-4: hl_range, close/open ratio
  /// 5-6: EMA(12), EMA(26)
  /// 7-8: MACD, RSI(14)
  /// 9-10: ATR(14), OBV normalized
  /// 11-12: volume_rel, volume_zscore
  /// 13-14: rolling_std_ret, rolling_mean_ret
  static List<List<double>> featuresFromCandles(
    List<Candle> window,
    int seqLen,
    int nFeatures,
  ) {
    // Take last seqLen candles
    final start = max(0, window.length - seqLen);
    final actualLen = min(seqLen, window.length - start);
    
    final closes = window.map((c) => c.close).toList();
    final opens = window.map((c) => c.open).toList();
    final highs = window.map((c) => c.high).toList();
    final lows = window.map((c) => c.low).toList();
    final vols = window.map((c) => c.volume).toList();
    
    // Pre-calculate indicators
    final ema12Values = _calculateEMASequence(closes, 12);
    final ema26Values = _calculateEMASequence(closes, 26);
    final rsi14Values = _calculateRSISequence(closes, 14);
    final atr14Values = _calculateATRSequence(window, 14);
    
    // Volume stats
    double smaVol = 0.0;
    for (int i = start; i < window.length; i++) {
      smaVol += vols[i];
    }
    smaVol /= actualLen;
    
    // Initialize output [seqLen, nFeatures]
    final out = List.generate(seqLen, (_) => List.filled(nFeatures, 0.0));
    
    // Fill features for each timestep
    for (int t = 0; t < actualLen; t++) {
      final i = start + t;
      final c = window[i];
      
      // Returns (3 periods)
      final ret1 = i > 0 ? (closes[i] / closes[i - 1]) - 1.0 : 0.0;
      final ret5 = i >= 5 ? (closes[i] / closes[i - 5]) - 1.0 : 0.0;
      final ret15 = i >= 15 ? (closes[i] / closes[i - 15]) - 1.0 : 0.0;
      
      // Price patterns
      final hlRange = c.low > 0 ? (c.high - c.low) / c.low : 0.0;
      final coRatio = c.open > 0 ? c.close / c.open - 1.0 : 0.0;
      
      // Indicators
      final ema12 = ema12Values[i];
      final ema26 = ema26Values[i];
      final macd = ema12 - ema26;
      final rsi14 = rsi14Values[i];
      final atr14 = atr14Values[i];
      
      // Volume features
      final obvNorm = i > 0 ? (c.volume - vols[i-1]) / max(c.volume, 1.0) : 0.0;
      final volRel = smaVol > 0 ? c.volume / smaVol : 1.0;
      final volZ = smaVol > 0 ? (c.volume - smaVol) / smaVol : 0.0;
      
      // Rolling statistics (last 10)
      final rollingRets = <double>[];
      for (int j = max(0, i - 10); j < i; j++) {
        if (j > 0) rollingRets.add((closes[j] / closes[j-1]) - 1.0);
      }
      final rollStd = rollingRets.isEmpty ? 0.0 : _std(rollingRets);
      final rollMean = rollingRets.isEmpty ? 0.0 : rollingRets.reduce((a,b)=>a+b) / rollingRets.length;
      
      // Assign features (15 total)
      out[t][0] = ret1;
      out[t][1] = ret5;
      out[t][2] = ret15;
      out[t][3] = hlRange;
      out[t][4] = coRatio;
      out[t][5] = ema12;
      out[t][6] = ema26;
      out[t][7] = macd;
      out[t][8] = rsi14;
      out[t][9] = atr14;
      out[t][10] = obvNorm;
      out[t][11] = volRel;
      out[t][12] = volZ;
      out[t][13] = rollStd;
      out[t][14] = rollMean;
      
      // Apply normalization (din stats.dart sau fallback)
      // TODO: Load real stats from training
    }
    
    return out;
  }
  
  // Helper: Calculate EMA for entire sequence
  static List<double> _calculateEMASequence(List<double> values, int period) {
    if (values.length < period) return List.filled(values.length, values.last);
    
    final k = 2.0 / (period + 1);
    final result = List<double>.filled(values.length, 0.0);
    
    // Initialize with SMA
    double emaVal = 0.0;
    for (int i = 0; i < period; i++) {
      emaVal += values[i];
    }
    emaVal /= period;
    result[period - 1] = emaVal;
    
    // Calculate EMA for rest
    for (int i = period; i < values.length; i++) {
      emaVal = values[i] * k + emaVal * (1 - k);
      result[i] = emaVal;
    }
    
    // Fill early values with first EMA
    for (int i = 0; i < period - 1; i++) {
      result[i] = result[period - 1];
    }
    
    return result;
  }
  
  // Helper: Calculate RSI for entire sequence
  static List<double> _calculateRSISequence(List<double> closes, int period) {
    if (closes.length < period + 1) return List.filled(closes.length, 50.0);
    
    final result = List<double>.filled(closes.length, 50.0);
    
    for (int i = period; i < closes.length; i++) {
      final slice = closes.sublist(max(0, i - period), i + 1);
      double gain = 0, loss = 0;
      
      for (int j = 1; j < slice.length; j++) {
        final diff = slice[j] - slice[j-1];
        if (diff > 0) {
          gain += diff;
        } else {
          loss -= diff;
        }
      }
      
      final avgGain = gain / period;
      final avgLoss = loss / period;
      final rs = avgLoss == 0 ? 100.0 : avgGain / avgLoss;
      result[i] = 100.0 - (100.0 / (1.0 + rs));
    }
    
    return result;
  }
  
  // Helper: Calculate ATR for entire sequence
  static List<double> _calculateATRSequence(List<Candle> candles, int period) {
    if (candles.length < period + 1) return List.filled(candles.length, 0.0);
    
    final result = List<double>.filled(candles.length, 0.0);
    
    for (int i = period; i < candles.length; i++) {
      double atrSum = 0.0;
      for (int j = max(1, i - period + 1); j <= i; j++) {
        final tr = candles[j].trueRange(candles[j-1]);
        atrSum += tr;
      }
      result[i] = atrSum / period;
    }
    
    return result;
  }
  
  // Helper: Standard deviation
  static double _std(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// Build input tensor based on model's expected shape
  /// Supports:
  /// - [1, F]           → 2D (aggregated features)
  /// - [1, T, F]        → 3D (sequence)
  /// - [1, T, F, 1]     → 4D (Conv2D format)
  /// - [1, T, F, C]     → 4D (Conv2D multi-channel)
  static dynamic buildInputTensor(
    List<Candle> window,
    List<int> inputShape,
  ) {
    final dims = inputShape.length;
    
    if (dims < 2 || inputShape[0] != 1) {
      debugPrint('⚠️ Unexpected input shape $inputShape');
      throw ArgumentError('Invalid input shape: $inputShape');
    }

    // Extract dimensions
    final seqLen = dims >= 3 ? inputShape[1] : min(kMinWindow, window.length);
    final nFeatures = dims >= 3 ? inputShape[2] : inputShape[1];
    final nChannels = dims >= 4 ? inputShape[3] : 1;

    // Get features matrix [seqLen, nFeatures]
    final features = featuresFromCandles(window, seqLen, nFeatures);

    // Build tensor based on dimensions
    if (dims == 2) {
      // [1, F] → Average over time
      final aggregated = List.filled(nFeatures, 0.0);
      for (int t = 0; t < features.length; t++) {
        for (int f = 0; f < nFeatures; f++) {
          aggregated[f] += features[t][f];
        }
      }
      for (int f = 0; f < nFeatures; f++) {
        aggregated[f] /= features.length;
      }
      return [aggregated];
    } else if (dims == 3) {
      // [1, T, F]
      return [features];
    } else if (dims == 4 && nChannels == 1) {
      // [1, T, F, 1] → Add channel dimension
      return [
        features.map((row) => row.map((val) => [val]).toList()).toList()
      ];
    } else {
      // [1, T, F, C] → Replicate features across channels
      return [
        features.map((row) =>
          row.map((val) => List.filled(nChannels, val)).toList()
        ).toList()
      ];
    }
  }

  /// Create empty output tensor based on shape
  static dynamic emptyOutput(List<int> outShape) {
    if (outShape.length == 2) {
      // [1, N]
      return List.generate(
        outShape[0],
        (_) => List.filled(outShape[1], 0.0),
      );
    } else if (outShape.length == 3) {
      // [1, T, N]
      return List.generate(
        outShape[0],
        (_) => List.generate(
          outShape[1],
          (_) => List.filled(outShape[2], 0.0),
        ),
      );
    } else if (outShape.length == 4) {
      // [1, T, N, C]
      return List.generate(
        outShape[0],
        (_) => List.generate(
          outShape[1],
          (_) => List.generate(
            outShape[2],
            (_) => List.filled(outShape[3], 0.0),
          ),
        ),
      );
    } else {
      throw ArgumentError('Unsupported output shape: $outShape');
    }
  }

  /// Extract scalar from potentially nested output
  static double extractScalar(dynamic output, List<int> outShape) {
    if (outShape.length == 2) {
      return (output[0][0] as num).toDouble();
    } else if (outShape.length == 3) {
      return (output[0][0][0] as num).toDouble();
    } else if (outShape.length == 4) {
      return (output[0][0][0][0] as num).toDouble();
    }
    return 0.0;
  }

  /// Extract probabilities from classification output
  static List<double> extractProbs(dynamic output, List<int> outShape, int numClasses) {
    List<double> probs;
    
    if (outShape.length == 2 && outShape[1] >= numClasses) {
      // [1, N] → output[0]
      probs = (output[0] as List).cast<num>().take(numClasses).map((e) => e.toDouble()).toList();
    } else if (outShape.length == 3) {
      // [1, 1, N] → output[0][0]
      probs = (output[0][0] as List).cast<num>().take(numClasses).map((e) => e.toDouble()).toList();
    } else if (outShape.length == 4) {
      // [1, 1, N, 1] → output[0][0][:, 0]
      probs = (output[0][0] as List).map((row) => (row[0] as num).toDouble()).take(numClasses).toList();
    } else {
      return List.filled(numClasses, 1.0 / numClasses); // Uniform fallback
    }
    
    // Normalize to sum = 1 (softmax normalization)
    final sum = probs.fold(0.0, (a, b) => a + b);
    if (sum > 0) {
      probs = probs.map((p) => p / sum).toList();
    }
    
    return probs;
  }
}

