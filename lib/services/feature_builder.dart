import 'dart:math';

class FeatureBuilder {
  static const int nfeat = 5; // last, ret1, sma5, sma20, rsi14
  const FeatureBuilder(
      [List<String> featCols = const [
        'last',
        'ret1',
        'sma5',
        'sma20',
        'rsi14'
      ]])
      : _featCols = featCols;

  final List<String> _featCols;

  Map<String, double> fromTicker({
    required double last,
    double? prev,
    double? sma5,
    double? sma20,
    double? rsi14,
  }) {
    final m = <String, double>{
      'last': last,
      'ret1': (prev == null) ? 0.0 : (last / prev - 1.0),
      'sma5': sma5 ?? last,
      'sma20': sma20 ?? last,
      'rsi14': rsi14 ?? 50.0,
    };
    final out = <String, double>{};
    for (final c in _featCols) {
      out[c] = m[c] ?? 0.0;
    }
    return out;
  }

  /// Build a 64xN feature sequence from klines closes (N = number of model features).
  /// We populate known columns: last, ret1, sma5, sma20, rsi14; unknowns become 0.
  List<List<double>> sequenceFromCloses(List<double> closes,
      {int length = 64}) {
    if (closes.length < length) {
      // Left-pad with the first value to reach required length
      final first = closes.isEmpty ? 0.0 : closes.first;
      closes = List<double>.filled(length - closes.length, first) + closes;
    } else if (closes.length > length) {
      closes = closes.sublist(closes.length - length);
    }

    // Helper indicators
    double sma(List<double> x, int idx, int p) {
      final start = max(0, idx - p + 1);
      final slice = x.sublist(start, idx + 1);
      final s = slice.fold<double>(0.0, (a, b) => a + b);
      return s / slice.length;
    }

    double rsi14At(int idx) {
      const p = 14;
      final int start = max(0, idx - p + 1);
      double gain = 0.0, loss = 0.0;
      for (int i = start + 1; i <= idx; i++) {
        final ch = closes[i] - closes[i - 1];
        if (ch >= 0) {
          gain += ch;
        } else {
          loss -= ch;
        }
      }
      if (gain == 0 && loss == 0) return 50.0;
      if (loss == 0) return 100.0;
      final rs = (gain / p) / (loss / p);
      return 100.0 - (100.0 / (1.0 + rs));
    }

    final seq = <List<double>>[];
    for (int i = 0; i < length; i++) {
      final last = closes[i];
      final prev = i == 0 ? last : closes[i - 1];
      final m = <String, double>{
        'last': last,
        'ret1': prev == 0 ? 0.0 : (last / prev - 1.0),
        'sma5': sma(closes, i, 5),
        'sma20': sma(closes, i, 20),
        'rsi14': rsi14At(i),
      };
      seq.add(_featCols.map((k) => m[k] ?? 0.0).toList());
    }
    return seq;
  }
}
