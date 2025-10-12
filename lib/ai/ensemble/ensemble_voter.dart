import 'dart:math' as math;

/// Simple geometric-mean voter between two probability triplets.
/// Returns normalized [pBuy, pHold, pSell]. If one side is null, returns the other.
List<double> geometricVote({
  required List<double> timeSeriesProbs, // [pBuy,pHold,pSell]
  List<double>? visionProbs, // optional
  double visionWeight = 0.5, // 0..1 (weight of vision vs time-series)
}) {
  if (visionProbs == null || visionProbs.length != 3) {
    return _normalize(timeSeriesProbs);
  }
  final ts = _normalize(timeSeriesProbs);
  final vs = _normalize(visionProbs);

  // Weighted geometric mean: p = exp( w*ln(vs) + (1-w)*ln(ts) )
  final w = visionWeight.clamp(0.0, 1.0);
  final out = List<double>.filled(3, 0.0);
  for (var i = 0; i < 3; i++) {
    final a = ts[i].clamp(1e-9, 1.0);
    final b = vs[i].clamp(1e-9, 1.0);
    out[i] = math.exp((1 - w) * math.log(a) + w * math.log(b));
  }
  return _normalize(out);
}

List<double> _normalize(List<double> p) {
  if (p.length != 3) return const [1 / 3, 1 / 3, 1 / 3];
  var s = p.fold<double>(0.0, (a, b) => a + (b.isFinite ? b : 0.0));
  if (s <= 0) return const [1 / 3, 1 / 3, 1 / 3];
  return [p[0] / s, p[1] / s, p[2] / s];
}
