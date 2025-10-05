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
  test('Platt reduces ECE on synthetic miscalibrated logits', () {
    final rnd = Random(1337);
    // Generate slightly overconfident logits
    final logits = List<double>.generate(5000, (_) => (rnd.nextDouble() - 0.5) * 3.0);
    List<double> sigmoid(List<double> z) => z.map((v) => 1.0 / (1.0 + exp(-v))).toList();
    final pRaw = sigmoid(logits);
    final y = pRaw.map((p) => rnd.nextDouble() < p ? 1 : 0).toList();

    // Platt with a<1 tends to reduce overconfidence
    const platt = PlattCalibrator(0.8, 0.0);
    final pCal = pRaw.map(platt.apply).toList();

    final eRaw = ece(pRaw, y, bins: 15);
    final eCal = ece(pCal, y, bins: 15);
    expect(eCal, lessThan(eRaw));
  });
}


