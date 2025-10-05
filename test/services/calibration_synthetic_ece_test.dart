import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/calibration.dart';

double ece(List<double> p, List<int> y, {int bins = 10}) {
  final n = p.length;
  final edges = List.generate(bins + 1, (i) => i / bins);
  double acc = 0;
  for (var b = 0; b < bins; b++) {
    final lo = edges[b], hi = edges[b + 1];
    final idx = <int>[];
    for (var i = 0; i < n; i++) {
      if ((p[i] >= lo) && (p[i] < (b == bins - 1 ? 1.0000001 : hi))) idx.add(i);
    }
    if (idx.isEmpty) continue;
    final avgP = idx.map((i) => p[i]).reduce((a, b) => a + b) / idx.length;
    final avgY = idx.map((i) => y[i]).reduce((a, b) => a + b) / idx.length;
    acc += (idx.length / n) * (avgP - avgY).abs();
  }
  return acc;
}

void main() {
  test('Platt reduces ECE on synthetic miscalibrated probabilities', () {
    final rnd = Random(1337);
    // Model emits raw probabilities pRaw ~ U(0,1)
    final pRaw = List<double>.generate(5000, (_) => rnd.nextDouble());
    // Ground truth is generated from a Platt-transformed probability of pRaw
    // i.e., true Bernoulli parameter = sigmoid(a*pRaw + b)
    const a = 0.8;
    const b = 0.0;
    double s(double z) => 1.0 / (1.0 + exp(-z));
    final pTrue = pRaw.map((p) => s(a * p + b)).toList();
    final y = pTrue.map((pt) => rnd.nextDouble() < pt ? 1 : 0).toList();

    // Calibrator with the same (a,b) should correct pRaw closer to pTrue
    const platt = PlattCalibrator(a, b);
    final pCal = pRaw.map(platt.apply).toList();

    final eRaw = ece(pRaw, y, bins: 15);
    final eCal = ece(pCal, y, bins: 15);
    expect(eCal, lessThan(eRaw));
  });
}


