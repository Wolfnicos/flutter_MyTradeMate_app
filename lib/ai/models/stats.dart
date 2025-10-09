/// Stats - Feature normalization parameters
/// Dacă ai parametri din training (mean/std), pune-i aici
/// Altfel folosește fallback (0 mean, 1 std)
class FeatureStats {
  /// Mean pentru fiecare feature (15 features)
  /// TODO: Replace cu valorile reale din training dacă le ai!
  static const List<double> mean = [
    0.0,    // 0: return_1
    0.0,    // 1: return_5
    0.0,    // 2: return_15
    0.0,    // 3: hl_range
    0.0,    // 4: co_ratio
    100.0,  // 5: ema12 (aprox price level)
    100.0,  // 6: ema26
    0.0,    // 7: macd
    50.0,   // 8: rsi14 (centered at 50)
    0.0,    // 9: atr14
    0.0,    // 10: obv_norm
    1.0,    // 11: volume_rel
    0.0,    // 12: volume_zscore
    0.0,    // 13: rolling_std_ret
    0.0,    // 14: rolling_mean_ret
  ];

  /// Standard deviation pentru fiecare feature
  static const List<double> std = [
    0.02,   // 0: return_1
    0.05,   // 1: return_5
    0.10,   // 2: return_15
    0.05,   // 3: hl_range
    0.02,   // 4: co_ratio
    50.0,   // 5: ema12
    50.0,   // 6: ema26
    0.5,    // 7: macd
    20.0,   // 8: rsi14
    5.0,    // 9: atr14
    0.5,    // 10: obv_norm
    0.5,    // 11: volume_rel
    1.0,    // 12: volume_zscore
    0.03,   // 13: rolling_std_ret
    0.02,   // 14: rolling_mean_ret
  ];

  /// Normalize a feature value
  static double normalize(double value, int featureIndex) {
    if (featureIndex < 0 || featureIndex >= mean.length) {
      return value; // No normalization
    }
    
    final m = mean[featureIndex];
    final s = std[featureIndex];
    
    if (s == 0) return value - m;
    
    return (value - m) / s;
  }

  /// Denormalize (inverse)
  static double denormalize(double normalized, int featureIndex) {
    if (featureIndex < 0 || featureIndex >= mean.length) {
      return normalized;
    }
    
    final m = mean[featureIndex];
    final s = std[featureIndex];
    
    return normalized * s + m;
  }
}

