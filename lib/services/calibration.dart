import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

abstract class Calibrator {
  double calibrate(double p);
}

class IdentityCalibrator implements Calibrator {
  const IdentityCalibrator();
  @override
  double calibrate(double p) => p.clamp(0.0, 1.0);
}

class PlattCalibrator implements Calibrator {
  final double a;
  final double b;
  const PlattCalibrator(this.a, this.b);
  @override
  double calibrate(double p) {
    final z = a * p + b;
    final v = 1.0 / (1.0 + math.exp(-z));
    return v.clamp(0.0, 1.0);
  }
}

class IsotonicCalibrator implements Calibrator {
  final List<double> xs; // monotonically increasing in [0,1]
  final List<double> ys; // corresponding calibrated values in [0,1]
  IsotonicCalibrator(this.xs, this.ys)
      : assert(xs.length == ys.length),
        assert(xs.length >= 2);

  @override
  double calibrate(double p) {
    if (p <= xs.first) return ys.first;
    if (p >= xs.last) return ys.last;
    int hi = xs.indexWhere((x) => x >= p);
    if (hi <= 0) return ys.first;
    final lo = hi - 1;
    final x0 = xs[lo], x1 = xs[hi];
    final y0 = ys[lo], y1 = ys[hi];
    final t = (p - x0) / (x1 - x0);
    final v = y0 + t * (y1 - y0);
    return v.clamp(0.0, 1.0);
  }
}

class CalibrationStore {
  static Future<Calibrator?> tryLoadFromAssets({String path = 'assets/models/calibration.json'}) async {
    try {
      final s = await rootBundle.loadString(path);
      final m = json.decode(s) as Map<String, dynamic>;
      final type = (m['type'] ?? '').toString().toLowerCase();
      switch (type) {
        case 'platt':
          final a = (m['a'] as num).toDouble();
          final b = (m['b'] as num).toDouble();
          return PlattCalibrator(a, b);
        case 'isotonic':
          final pts = (m['points'] as List).cast<List>();
          final xs = <double>[];
          final ys = <double>[];
          for (final p in pts) {
            xs.add((p[0] as num).toDouble());
            ys.add((p[1] as num).toDouble());
          }
          return IsotonicCalibrator(xs, ys);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class ReliabilityBin {
  final double lo, hi;
  final int n;
  final double meanPred, meanTrue;
  const ReliabilityBin(this.lo, this.hi, this.n, this.meanPred, this.meanTrue);
}

List<ReliabilityBin> reliabilityBins(List<double> p, List<int> y, {int bins = 15}) {
  final n = p.length;
  final out = <ReliabilityBin>[];
  for (var b = 0; b < bins; b++) {
    final lo = b / bins, hi = (b + 1) / bins;
    double sP = 0, sY = 0; int k = 0;
    for (var i = 0; i < n; i++) {
      final v = p[i];
      final inLast = b == bins - 1 ? (v >= lo && v <= hi) : (v >= lo && v < hi);
      if (inLast) { sP += v; sY += y[i]; k++; }
    }
    if (k == 0) continue;
    out.add(ReliabilityBin(lo, hi, k, sP / k, sY / k));
  }
  return out;
}

double expectedCalibrationError(List<ReliabilityBin> bins, int total) {
  double s = 0.0;
  for (final b in bins) {
    s += (b.n / total) * (b.meanPred - b.meanTrue).abs();
  }
  return s;
}



