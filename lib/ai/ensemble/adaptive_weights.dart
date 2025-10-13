class AdaptiveWeights {
  Map<String, double> modelWeights = {
    '5m': 0.15,
    '15m': 0.20,
    '1h': 0.25,
    '4h': 0.25,
    'vision': 0.15,
  };

  void updateWeights(Map<String, double> recentPerformance) {
    final updated = <String, double>{};
    modelWeights.forEach((model, w) {
      final perf = recentPerformance[model] ?? 0.0; // 0..1 expected
      final m = (0.9 + perf * 0.2);
      updated[model] = (w * m).clamp(0.0, 1.0);
    });
    modelWeights = updated;
    normalizeWeights();
  }

  void normalizeWeights() {
    final sum = modelWeights.values.fold<double>(0.0, (p, c) => p + c);
    if (sum <= 0) return;
    modelWeights = modelWeights.map((k, v) => MapEntry(k, v / sum));
  }
}


