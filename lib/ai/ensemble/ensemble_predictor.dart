import 'package:flutter/foundation.dart';

import '../entities.dart';
import '../models/direction_model.dart';
import '../models/return_model.dart';
import '../models/volatility_model.dart';
import 'ensemble_result.dart';
import 'model_weights.dart';
import 'performance_tracker.dart';

/// Lightweight vote used by combine()
/// direction: 'BUY' | 'SELL' | 'HOLD'; confidence in [0..1]
class SignalVote {
  final String direction;
  final double confidence;
  const SignalVote({required this.direction, required this.confidence});
}

/// Result for combine() helper
class CombineResult {
  final double confidence;
  final Map<String, dynamic> metadata;
  const CombineResult(this.confidence, this.metadata);
}

/// EnsemblePredictor combines multiple models using weighted voting/averaging.
class EnsemblePredictor {
  final DirectionModel dirModel;
  final ReturnModel retModel;
  final VolatilityModel volModel;
  final ModelWeights weights;
  final PerformanceTracker tracker;
  final double boost;
  final double penalty;

  const EnsemblePredictor({
    required this.dirModel,
    required this.retModel,
    required this.volModel,
    required this.weights,
    required this.tracker,
    this.boost = CONSENSUS_BOOST,
    this.penalty = CONSENSUS_PENALTY,
  });

  // Public constants for tests and tuning
  static const double CONSENSUS_BOOST = 0.15;
  static const double CONSENSUS_PENALTY = 0.10;

  /// Pure weighted combination for unit-testing without running models.
  /// Expects [models] length 3 in order: Direction, Return, Volatility.
  CombineResult combine(List<SignalVote> models, SignalVote fallback) {
    // Map a vote to BUY-confidence space
    double asBuy(SignalVote v) {
      final d = v.direction.toUpperCase();
      if (d == 'BUY') return v.confidence;
      if (d == 'SELL') return 1.0 - v.confidence;
      return 0.5; // HOLD treated neutral
    }

    final dirC = models.isNotEmpty ? asBuy(models[0]) : 0.33;
    final retC = models.length > 1 ? asBuy(models[1]) : 0.33;
    final volC = models.length > 2 ? asBuy(models[2]) : 0.33;
    final techC = asBuy(fallback);

    final base = weights.dir * dirC +
        weights.ret * retC +
        weights.vol * volC +
        weights.tech * techC;

    final allDirs = models.map((m) => m.direction.toUpperCase()).toSet();
    double conf = base;
    bool boost = false, penalty = false;
    if (allDirs.length == 1) {
      conf = (conf + CONSENSUS_BOOST).clamp(0.0, 1.0);
      boost = true;
    } else {
      conf = (conf - CONSENSUS_PENALTY).clamp(0.0, 1.0);
      penalty = true;
    }

    return CombineResult(conf, {
      'base': base,
      'boost_applied': boost,
      'penalty_applied': penalty,
      'weights': {
        'dir': weights.dir,
        'ret': weights.ret,
        'vol': weights.vol,
        'tech': weights.tech
      },
    });
  }

  Future<EnsembleResult> predict(List<Candle> window) async {
    // Collect per-model outputs; any failure is handled gracefully
    List<double> pDir = const [1 / 3, 1 / 3, 1 / 3];
    double eRet = 0.0;
    double aVol = 0.3; // neutral 30%
    bool dirOk = false, retOk = false, volOk = false;

    try {
      pDir = await dirModel.predictProbs(window);
      dirOk = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Ensemble: DirectionModel failed: $e');
    }
    try {
      eRet = await retModel.predictReturn(window);
      retOk = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Ensemble: ReturnModel failed: $e');
    }
    try {
      aVol = await volModel.predictVolatility(window);
      volOk = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Ensemble: VolatilityModel failed: $e');
    }

    // Technical fallback as a direction proxy if needed
    final techProbs = _technicalFallback(window);

    // Weighted direction voting (probabilities)
    final wDir = weights.dir * (dirOk ? 1.0 : 0.0);
    final wTech = weights.tech; // always available
    final dirVec = [
      wDir * pDir[0] + wTech * techProbs[0],
      wDir * pDir[1] + wTech * techProbs[1],
      wDir * pDir[2] + wTech * techProbs[2],
    ];
    final dirSum = dirVec.fold<double>(0.0, (a, b) => a + b);
    final pEns = dirSum == 0.0
        ? const [1 / 3, 1 / 3, 1 / 3]
        : dirVec.map((x) => x / dirSum).toList();

    // Weighted averaging for return & vol
    final wRet = weights.ret * (retOk ? 1.0 : 0.0);
    final wVol = weights.vol * (volOk ? 1.0 : 0.0);
    final denom = (wRet + wVol).clamp(1e-9, 1e9);
    final expRet = (wRet * eRet + wVol * (0.0)) /
        denom; // no tech return, keep 0.0 baseline
    final annVol = (wVol * aVol + wRet * 0.3) /
        denom; // bias towards 30% if return dominates

    // Agreement boosting / disagreement penalty
    final maxP = pEns.reduce((a, b) => a > b ? a : b);
    double confidence = maxP; // base
    final agree = _agreement([pDir, techProbs]);
    if (agree > 0.8) confidence = (confidence + boost).clamp(0.0, 1.0);
    if (agree < 0.5) confidence = (confidence - penalty).clamp(0.0, 1.0);

    return EnsembleResult(
      probs: [pEns[0], pEns[1], pEns[2]],
      expReturn: expRet,
      annVol: annVol,
      confidence: confidence,
      debug: {
        'dirOk': dirOk,
        'retOk': retOk,
        'volOk': volOk,
        'weights': {
          'dir': weights.dir,
          'ret': weights.ret,
          'vol': weights.vol,
          'tech': weights.tech
        },
        'agree': agree,
      },
    );
  }

  double _agreement(List<List<double>> probs) {
    if (probs.isEmpty) return 0.0;
    final avg = List<double>.filled(3, 0.0);
    for (final p in probs) {
      for (int i = 0; i < 3; i++) {
        avg[i] += p[i];
      }
    }
    for (int i = 0; i < 3; i++) {
      avg[i] /= probs.length;
    }
    // Measure concentration via max probability
    return avg.reduce((a, b) => a > b ? a : b);
  }

  List<double> _technicalFallback(List<Candle> candles) {
    if (candles.length < 26) return const [0.33, 0.34, 0.33];
    final closes = candles.map((c) => c.close).toList();
    final ema12 = _ema(closes, 12);
    final ema26 = _ema(closes, 26);
    final rsi = _rsi(closes, 14);
    if (ema12 > ema26 && rsi > 50) return const [0.55, 0.30, 0.15];
    if (ema12 < ema26 && rsi < 50) return const [0.15, 0.30, 0.55];
    return const [0.33, 0.34, 0.33];
  }

  double _ema(List<double> v, int period) {
    if (v.isEmpty) return 0.0;
    final k = 2.0 / (period + 1);
    double e = v.first;
    for (final x in v.skip(1)) {
      e = x * k + e * (1 - k);
    }
    return e;
  }

  double _rsi(List<double> c, int period) {
    if (c.length <= period) return 50.0;
    double g = 0, l = 0;
    for (int i = c.length - period; i < c.length; i++) {
      final d = c[i] - c[i - 1];
      if (d >= 0) {
        g += d;
      } else {
        l += -d;
      }
    }
    if (l == 0) return 100.0;
    final rs = (g / period) / (l / period);
    return 100.0 - (100.0 / (1.0 + rs));
  }
}
