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

enum SignalAction { buy, hold, sell }

class Consensus {
  final SignalAction action;
  final double confidence;
  const Consensus(this.action, this.confidence);
}

class EnsembleResolver {
  const EnsembleResolver();

  Consensus calculateConsensus(Map<String, double> tsProbs) {
    final pBuy = tsProbs['buy'] ?? 0.0;
    final pHold = tsProbs['hold'] ?? 0.0;
    final pSell = tsProbs['sell'] ?? 0.0;
    SignalAction a;
    double c;
    if (pBuy >= pSell && pBuy >= pHold) {
      a = SignalAction.buy; c = pBuy;
    } else if (pSell >= pBuy && pSell >= pHold) {
      a = SignalAction.sell; c = pSell;
    } else {
      a = SignalAction.hold; c = pHold;
    }
    return Consensus(a, c);
  }

  SignalAction _strongest(List<double> probs) {
    if (probs.length < 3) return SignalAction.hold;
    final i = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    if (i == 0) return SignalAction.buy;
    if (i == 2) return SignalAction.sell;
    return SignalAction.hold;
  }

  SignalAction resolveConflict(Map<String, double> tsProbs, List<double> visionProbs) {
    final visionStrength = visionProbs.reduce((a, b) => a > b ? a : b);
    final tsConsensus = calculateConsensus(tsProbs);
    final visAction = _strongest(visionProbs);

    // If vision is very confident (>0.7) and disagrees with a confident TS (>0.6), stand down
    if (visionStrength > 0.7 && tsConsensus.confidence > 0.6) {
      if (visAction != tsConsensus.action) {
        return SignalAction.hold;
      }
    }

    // Default to TS consensus action
    return tsConsensus.action;
  }
}
