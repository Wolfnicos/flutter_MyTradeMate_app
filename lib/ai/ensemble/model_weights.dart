import 'package:flutter/foundation.dart';

/// Adaptive model weights with simple exponential moving average on accuracy.
class ModelWeights {
  // Initial weights per spec
  // Default to direction-only until return/volatility are calibrated
  double dir = 1.0;
  double ret = 0.0;
  double vol = 0.0;
  double tech = 0.0;

  // Running accuracy estimates [0..1]
  double accDir = 0.5;
  double accRet = 0.5;
  double accVol = 0.5;
  double accTech = 0.5;

  /// Update accuracies (EMA) and derive normalized weights.
  void update({double? dirHit, double? retHit, double? volHit, double? techHit, double alpha = 0.1}) {
    if (dirHit != null) accDir = _ema(accDir, dirHit, alpha);
    if (retHit != null) accRet = _ema(accRet, retHit, alpha);
    if (volHit != null) accVol = _ema(accVol, volHit, alpha);
    if (techHit != null) accTech = _ema(accTech, techHit, alpha);

    // Map accuracies to weights around the base priors
    final base = [0.35, 0.25, 0.20, 0.20];
    final acc = [accDir, accRet, accVol, accTech];
    final raw = <double>[];
    for (int i = 0; i < base.length; i++) {
      raw.add((base[i] * (0.5 + acc[i]))); // favor models with higher accuracy
    }
    final sum = raw.fold<double>(0.0, (a, b) => a + b);
    dir = raw[0] / sum;
    ret = raw[1] / sum;
    vol = raw[2] / sum;
    tech = raw[3] / sum;

    if (kDebugMode) {
      debugPrint('🧮 Weights updated: dir=$dir ret=$ret vol=$vol tech=$tech');
    }
  }

  double _ema(double prev, double hit, double alpha) => prev * (1 - alpha) + hit * alpha;
}


