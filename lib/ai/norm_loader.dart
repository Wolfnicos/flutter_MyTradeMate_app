import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class NormSpec {
  final List<String> featureOrder;
  final Map<String, double> mean;
  final Map<String, double> std;
  const NormSpec(
      {required this.featureOrder, required this.mean, required this.std});
}

class NormLoader {
  static NormSpec? _cached;

  static Future<NormSpec> ensureLoaded() async {
    if (_cached != null) return _cached!;

    Map<String, dynamic>? norm;
    try {
      final s = await rootBundle.loadString('assets/models/norm.json');
      norm = json.decode(s) as Map<String, dynamic>;
    } catch (_) {
      norm = null;
    }

    List<dynamic>? foDyn;
    try {
      final s = await rootBundle.loadString('assets/models/feat_cols.json');
      final m = json.decode(s) as Map<String, dynamic>;
      foDyn = (m['feature_order'] as List?) ?? (m['features'] as List?);
    } catch (_) {
      foDyn = null;
    }

    final List<String> featureOrder = (() {
      if (foDyn != null) return foDyn.map((e) => e.toString()).toList();
      if (norm != null && norm!['feature_order'] is List) {
        return (norm!['feature_order'] as List)
            .map((e) => e.toString())
            .toList();
      }
      return const [
        'open',
        'high',
        'low',
        'close',
        'volume',
        'ret_1',
        'ema9',
        'ema21',
        'atr'
      ];
    })();

    final Map<String, double> mean = {};
    final Map<String, double> std = {};
    if (norm != null) {
      final m = (norm!['mean'] as Map?) ?? {};
      final s = (norm!['std'] as Map?) ?? {};
      for (final k in featureOrder) {
        mean[k] = (m[k] as num?)?.toDouble() ?? 0.0;
        std[k] = ((s[k] as num?)?.toDouble() ?? 1.0);
        if (std[k]! == 0.0) std[k] = 1.0;
      }
    } else {
      for (final k in featureOrder) {
        mean[k] = 0.0;
        std[k] = 1.0;
      }
    }

    _cached = NormSpec(featureOrder: featureOrder, mean: mean, std: std);
    // Print success once on startup with the number of features
    // ignore: avoid_print
    print(
        '✅ AI normalization loaded successfully with ${featureOrder.length} features.');
    return _cached!;
  }

  static List<String> getFeatureOrderSyncOrFallback() {
    if (_cached != null) return _cached!.featureOrder;
    return const [
      'open',
      'high',
      'low',
      'close',
      'volume',
      'ret_1',
      'ema9',
      'ema21',
      'atr'
    ];
  }
}
