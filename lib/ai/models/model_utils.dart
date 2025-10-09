import 'dart:math';
import '../entities.dart';
import 'stats.dart';

class ModelUtils {
  /// Extract features from candles for model input
  /// Returns: List of [windowSize] timesteps, each with [numFeatures] features
  static List<List<double>> featuresFromCandles(
    List<Candle> candles,
    int windowSize,
    int numFeatures,
  ) {
    if (candles.length < windowSize) {
      throw ArgumentError(
        'Need at least $windowSize candles, got ${candles.length}',
      );
    }

    // Take the last windowSize candles
    final window = candles.sublist(candles.length - windowSize);
    
    final features = <List<double>>[];
    
    for (int i = 0; i < windowSize; i++) {
      final timestepFeatures = _extractTimestepFeatures(window, i);
      
      if (timestepFeatures.length != numFeatures) {
        throw StateError(
          'Expected $numFeatures features, got ${timestepFeatures.length} at timestep $i',
        );
      }
      
      features.add(timestepFeatures);
    }

    return features;
  }

  /// Normalize 2D features using training statistics
  static List<double> normalize2D(List<List<double>> features) {
    // Delegate to NormalizationStats which handles the entire 2D array
    return NormalizationStats.normalize2D(features);
  }

  /// Extract features for a single timestep
  static List<double> _extractTimestepFeatures(
    List<Candle> window,
    int idx,
  ) {
    final current = window[idx];
    final features = <double>[];

    // Feature 0-2: Returns (ret1, ret5, ret15)
    features.add(_getReturn(window, idx, 1));
    features.add(_getReturn(window, idx, 5));
    features.add(_getReturn(window, idx, 15));

    // Feature 3: HL range (normalized by close)
    final hlRange = (current.high - current.low) / current.close;
    features.add(hlRange);

    // Feature 4: CO ratio
    final coRatio = current.close / current.open;
    features.add(coRatio);

    // Feature 5-6: EMAs (normalized by close for stability)
    final ema12 = _calculateEMA(window.sublist(0, idx + 1), 12);
    final ema26 = _calculateEMA(window.sublist(0, idx + 1), 26);
    features.add(ema12 / current.close); // Relative EMA
    features.add(ema26 / current.close);

    // Feature 7: MACD (normalized by close)
    final macd = (ema12 - ema26) / current.close;
    features.add(macd);

    // Feature 8: RSI (already bounded [0, 100])
    final rsi = _calculateRSI(window.sublist(0, idx + 1), 14);
    features.add(rsi);

    // Feature 9: ATR (normalized by close)
    final atr = _calculateATR(window.sublist(0, idx + 1), 14);
    features.add(atr / current.close);

    // Feature 10: OBV normalized
    final obvNorm = _calculateOBVNorm(window.sublist(0, idx + 1));
    features.add(obvNorm);

    // Feature 11-12: Volume metrics
    final avgVol = window.map((c) => c.volume).reduce((a, b) => a + b) / window.length;
    final volumeRel = current.volume / (avgVol + 1e-10); // Avoid division by zero
    final volumeZ = (current.volume - avgVol) / (avgVol + 1e-10);
    features.add(volumeRel);
    features.add(volumeZ);

    // Feature 13-14: Rolling statistics (normalized by close)
    final closes = window.sublist(0, idx + 1).map((c) => c.close).toList();
    final rollingStd = _std(closes) / current.close;
    final rollingMean = _mean(closes) / current.close;
    features.add(rollingStd);
    features.add(rollingMean);

    return features;
  }

  /// Calculate return over N periods
  static double _getReturn(List<Candle> window, int idx, int periods) {
    if (idx < periods) {
      return 0.0; // Not enough history
    }
    
    final current = window[idx].close;
    final past = window[idx - periods].close;
    
    if (past == 0) return 0.0;
    
    return (current - past) / past;
  }

  /// Calculate Exponential Moving Average
  static double _calculateEMA(List<Candle> data, int period) {
    if (data.isEmpty) return 0.0;
    if (data.length < period) return data.last.close;

    final alpha = 2.0 / (period + 1);
    double ema = data[0].close;

    for (int i = 1; i < data.length; i++) {
      ema = data[i].close * alpha + ema * (1 - alpha);
    }

    return ema;
  }

  /// Calculate Relative Strength Index
  static double _calculateRSI(List<Candle> data, int period) {
    if (data.length < period + 1) return 50.0; // Neutral RSI

    double gains = 0;
    double losses = 0;

    for (int i = data.length - period; i < data.length; i++) {
      if (i == 0) continue;
      
      final change = data[i].close - data[i - 1].close;
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

  /// Calculate Average True Range
  static double _calculateATR(List<Candle> data, int period) {
    if (data.length < 2) return data.last.high - data.last.low;
    if (data.length < period + 1) {
      return data.last.high - data.last.low;
    }

    final trs = <double>[];
    
    for (int i = 1; i < data.length; i++) {
      final high = data[i].high;
      final low = data[i].low;
      final prevClose = data[i - 1].close;

      final tr = [
        high - low,
        (high - prevClose).abs(),
        (low - prevClose).abs(),
      ].reduce((a, b) => a > b ? a : b);

      trs.add(tr);
    }

    final recentTRs = trs.length > period 
        ? trs.sublist(trs.length - period)
        : trs;
    
    return recentTRs.reduce((a, b) => a + b) / recentTRs.length;
  }

  /// Calculate normalized On-Balance Volume
  static double _calculateOBVNorm(List<Candle> data) {
    if (data.length < 2) return 0.5; // Neutral

    double obv = 0;
    
    for (int i = 1; i < data.length; i++) {
      if (data[i].close > data[i - 1].close) {
        obv += data[i].volume;
      } else if (data[i].close < data[i - 1].close) {
        obv -= data[i].volume;
      }
      // If equal, OBV doesn't change
    }

    // Normalize to [0, 1] range
    // Max possible OBV would be sum of all volumes
    final maxObv = data.map((c) => c.volume).reduce((a, b) => a + b);
    
    if (maxObv == 0) return 0.5;
    
    // Map from [-maxObv, +maxObv] to [0, 1]
    return (obv / maxObv + 1) / 2;
  }

  /// Calculate mean of a list
  static double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation
  static double _std(List<double> values) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return 0.0;
    
    final mean = _mean(values);
    final variance = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return sqrt(variance);
  }

  // ========================================================================
  // BACKWARDS COMPATIBILITY for ReturnModel and VolatilityModel
  // ========================================================================

  /// Build input tensor with explicit shape (legacy method)
  static dynamic buildInputTensor(List<Candle> window, List<int> inShape) {
    // Extract features using new method
    final windowSize = inShape[1]; // [1, 64, 15]
    final numFeatures = inShape[2];
    
    final feats = featuresFromCandles(window, windowSize, numFeatures);
    final flat = normalize2D(feats);
    
    // Reshape according to inShape
    if (inShape.length == 3) {
      // [1, timesteps, features]
      return _reshapeTo3D(flat, inShape);
    } else if (inShape.length == 4) {
      // [1, timesteps, features, channels]
      return _reshapeTo4D(flat, inShape);
    }
    
    throw ArgumentError('Unsupported input shape: $inShape');
  }

  /// Create empty output tensor of given shape
  static dynamic emptyOutput(List<int> outShape) {
    if (outShape.length == 1) {
      return List.filled(outShape[0], 0.0);
    } else if (outShape.length == 2) {
      return List.generate(
        outShape[0],
        (_) => List.filled(outShape[1], 0.0),
      );
    } else if (outShape.length == 3) {
      return List.generate(
        outShape[0],
        (_) => List.generate(
          outShape[1],
          (_) => List.filled(outShape[2], 0.0),
        ),
      );
    }
    
    throw ArgumentError('Unsupported output shape: $outShape');
  }

  /// Extract scalar value from output tensor
  static double extractScalar(dynamic output, List<int> outShape) {
    if (outShape.length == 1) {
      // [1] -> output[0]
      return (output as List<double>)[0];
    } else if (outShape.length == 2) {
      // [1, 1] -> output[0][0]
      return (output as List<List<double>>)[0][0];
    } else if (outShape.length == 3) {
      // [1, 1, 1] -> output[0][0][0]
      return (output as List<List<List<double>>>)[0][0][0];
    }
    
    throw ArgumentError('Cannot extract scalar from shape: $outShape');
  }

  static List<List<List<double>>> _reshapeTo3D(
    List<double> flat,
    List<int> shape,
  ) {
    final result = <List<List<double>>>[];
    int idx = 0;

    for (int b = 0; b < shape[0]; b++) {
      final batch = <List<double>>[];
      for (int t = 0; t < shape[1]; t++) {
        final timestep = <double>[];
        for (int f = 0; f < shape[2]; f++) {
          timestep.add(idx < flat.length ? flat[idx++] : 0.0);
        }
        batch.add(timestep);
      }
      result.add(batch);
    }

    return result;
  }

  static List<List<List<List<double>>>> _reshapeTo4D(
    List<double> flat,
    List<int> shape,
  ) {
    final result = <List<List<List<double>>>>[];
    int idx = 0;

    for (int b = 0; b < shape[0]; b++) {
      final batch = <List<List<double>>>[];
      for (int t = 0; t < shape[1]; t++) {
        final timestep = <List<double>>[];
        for (int f = 0; f < shape[2]; f++) {
          final channel = <double>[];
          for (int c = 0; c < shape[3]; c++) {
            channel.add(idx < flat.length ? flat[idx++] : 0.0);
          }
          timestep.add(channel);
        }
        batch.add(timestep);
      }
      result.add(batch);
    }

    return result;
  }
}

