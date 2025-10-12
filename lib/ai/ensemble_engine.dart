import 'entities.dart';
import 'indicators.dart';
import 'models/direction_model.dart';
import 'models/return_model.dart';
import 'models/volatility_model.dart';

/// Unified output used by ensemble to aggregate model votes
class EnsembleOutput {
  final List<double> probs; // [pBuy, pHold, pSell]
  final double expReturn; // fraction (e.g., 0.012 = 1.2%)
  final double annVol; // annualized (e.g., 0.65 = 65%)
  final double confidence; // 0..1

  const EnsembleOutput({
    required this.probs,
    required this.expReturn,
    required this.annVol,
    required this.confidence,
  });
}

/// Contract for any predictor that can feed the ensemble
abstract class EnsemblePredictor {
  Future<EnsembleOutput> predict(List<Candle> window);
}

/// Wrapper around existing Direction/Return/Volatility models
class DRVPredictor implements EnsemblePredictor {
  final DirectionModel dirModel;
  final ReturnModel retModel;
  final VolatilityModel volModel;

  DRVPredictor({
    required this.dirModel,
    required this.retModel,
    required this.volModel,
  });

  @override
  Future<EnsembleOutput> predict(List<Candle> window) async {
    final probs = await dirModel.predictProbs(window);
    final expReturn = await retModel.predictReturn(window);
    final annVol = await volModel.predictVolatility(window);
    final conf = _confidenceFromProbs(probs, annVol);
    return EnsembleOutput(
      probs: probs,
      expReturn: expReturn,
      annVol: annVol,
      confidence: conf,
    );
  }

  double _confidenceFromProbs(List<double> p, double annVol) {
    final maxProb = p.reduce((a, b) => a > b ? a : b);
    const volCap = 0.85;
    final volPenalty = (1.0 - (annVol / volCap).clamp(0.0, 1.0));
    return (maxProb * volPenalty).clamp(0.0, 1.0);
  }
}

class EnsembleEngine {
  final List<EnsemblePredictor> predictors;

  const EnsembleEngine({required this.predictors});

  /// Combine multiple model votes into a single Prediction
  Future<Prediction> predict(String symbol, List<Candle> window) async {
    if (window.length < 64) {
      throw ArgumentError('Not enough candles for ensemble (need >=64)');
    }

    // Run predictors in parallel
    final outputs = await Future.wait(
      predictors.map((p) => p.predict(window)),
    );

    final weights = _getWeightsForSymbol(symbol, outputs.length);
    final combined = _weightedAverage(outputs, weights);
    final calibrated = _plattScaling(combined, symbol);

    // Compose final Prediction
    final rv = relativeVolume(window, period: 20);
    return Prediction(
      symbol: symbol,
      asOf: window.last.time,
      pBuy: calibrated.probs[0],
      pHold: calibrated.probs[1],
      pSell: calibrated.probs[2],
      expReturn: calibrated.expReturn,
      annVol: calibrated.annVol,
      relVolume: rv,
    );
  }

  List<double> _getWeightsForSymbol(String symbol, int n) {
    // Placeholder: equal weights; replace with backtest-derived weights per symbol
    if (n <= 0) return const [];
    return List<double>.filled(n, 1.0 / n);
  }

  EnsembleOutput _weightedAverage(List<EnsembleOutput> outs, List<double> w) {
    double buy = 0, hold = 0, sell = 0;
    double expR = 0, vol = 0, conf = 0;
    for (var i = 0; i < outs.length; i++) {
      final oi = outs[i];
      final wi = i < w.length ? w[i] : 0.0;
      buy += oi.probs[0] * wi;
      hold += oi.probs[1] * wi;
      sell += oi.probs[2] * wi;
      expR += oi.expReturn * wi;
      vol += oi.annVol * wi;
      conf += oi.confidence * wi;
    }
    final sum = buy + hold + sell;
    if (sum > 0) {
      buy /= sum;
      hold /= sum;
      sell /= sum;
    } else {
      buy = hold = sell = 1.0 / 3.0;
    }
    return EnsembleOutput(
      probs: [buy, hold, sell],
      expReturn: expR,
      annVol: vol.clamp(0.01, 3.0),
      confidence: conf.clamp(0.0, 1.0),
    );
  }

  EnsembleOutput _plattScaling(EnsembleOutput o, String symbol) {
    // Placeholder calibration; replace with symbol-specific Platt params
    return o;
  }
}
