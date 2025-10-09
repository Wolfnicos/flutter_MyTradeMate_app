/// Stats - Feature normalization parameters
/// Dacă ai parametri din training (mean/std), pune-i aici
/// Altfel folosește fallback (0 mean, 1 std)
// REPLACEMENT cu statistici reale de training pentru crypto
class NormalizationStats {
  // CRITICAL: Aceste valori TREBUIE să vină din datele de training!
  // Momentan sunt estimate pentru BTC/ETH la timeframe 5m-1h
  
  // Ordinea features (trebuie să match cu ModelUtils.featuresFromCandles):
  // 0: ret1, 1: ret5, 2: ret15, 3: hl_range, 4: co_ratio,
  // 5: ema12, 6: ema26, 7: macd, 8: rsi14, 9: atr14,
  // 10: obv_norm, 11: volume_rel, 12: volume_z, 13: rolling_std, 14: rolling_mean
  
  static const List<double> means = [
    0.0,      // ret1 - returns sunt mean ~0
    0.0,      // ret5
    0.0,      // ret15
    0.015,    // hl_range - 1.5% average range
    1.0,      // co_ratio - close/open ratio ~1
    1.0,      // ema12 - normalized to price, so ~1
    1.0,      // ema26
    0.0,      // macd - difference, mean ~0
    50.0,     // rsi14 - bounded [0,100], mean ~50
    0.02,     // atr14 - normalized to price, ~2%
    0.5,      // obv_norm - normalized to [0,1], mean ~0.5
    1.0,      // volume_rel - relative to avg, mean ~1
    0.0,      // volume_z - z-score, mean ~0
    0.015,    // rolling_std - normalized to price, ~1.5%
    1.0,      // rolling_mean - normalized to price, ~1
  ];

  static const List<double> stds = [
    0.008,    // ret1 - ~0.8% volatility per period
    0.015,    // ret5 - ~1.5% over 5 periods
    0.025,    // ret15 - ~2.5% over 15 periods
    0.008,    // hl_range
    0.005,    // co_ratio
    0.05,     // ema12 - 5% variation in relative EMA
    0.05,     // ema26
    0.01,     // macd
    15.0,     // rsi14 - typical RSI std ~15
    0.01,     // atr14
    0.2,      // obv_norm
    0.4,      // volume_rel - can spike 2-3x
    1.0,      // volume_z - by definition ~1
    0.008,    // rolling_std
    0.05,     // rolling_mean
  ];

  /// Normalize a flat list of features using training statistics
  static List<double> normalize(List<double> features) {
    if (features.length != means.length) {
      throw ArgumentError(
        'Features length ${features.length} does not match expected ${means.length}',
      );
    }

    final normalized = <double>[];
    
    for (int i = 0; i < features.length; i++) {
      final std = stds[i];
      
      if (std == 0 || std.isNaN || std.isInfinite) {
        normalized.add(0.0);
        continue;
      }
      
      final value = features[i];
      
      if (value.isNaN || value.isInfinite) {
        normalized.add(0.0);
        continue;
      }
      
      final z = (value - means[i]) / std;
      final clamped = z.clamp(-5.0, 5.0);
      normalized.add(clamped);
    }

    return normalized;
  }

  /// Normalize a 2D array (timesteps × features)
  static List<double> normalize2D(List<List<double>> features) {
    final flat = <double>[];
    
    for (final timestep in features) {
      final normalized = normalize(timestep);
      flat.addAll(normalized);
    }
    
    return flat;
  }

  /// Get statistics summary for debugging
  static String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Normalization Statistics:');
    buffer.writeln('Features: ${means.length}');
    
    for (int i = 0; i < means.length; i++) {
      buffer.writeln('  [$i] mean=${means[i].toStringAsFixed(4)}, std=${stds[i].toStringAsFixed(4)}');
    }
    
    return buffer.toString();
  }
}


