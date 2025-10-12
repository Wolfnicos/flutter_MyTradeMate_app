import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'engine_interface.dart';
import 'models/direction_model.dart';
import 'models/return_model.dart';
import 'models/volatility_model.dart';
import 'indicators.dart';
import 'ensemble/ensemble_predictor.dart';
import 'ensemble/model_weights.dart';
import 'ensemble/performance_tracker.dart';
import 'ensemble/ensemble_result.dart';

/// SignalEngine - Core ML pipeline pentru trading signals
/// Combină 3 modele: Direction, Return, Volatility
class SignalEngine implements ISignalEngine {
  final DirectionModel dirModel;
  final ReturnModel? returnModel;
  final VolatilityModel? volatilityModel;
  final EnsemblePredictor? ensemble; // optional ensemble layer
  final StrategySettings settings;
  List<Candle>? _lastWindow; // for decision helpers

  SignalEngine({
    required this.dirModel,
    this.returnModel,
    this.volatilityModel,
    this.ensemble,
    this.settings = const StrategySettings(),
  });

  /// Factory cu toate modelele
  factory SignalEngine.full({StrategySettings? settings}) {
    final dir = DirectionModel();
    final ret = ReturnModel();
    final vol = VolatilityModel();
    final ens = EnsemblePredictor(
      dirModel: dir,
      retModel: ret,
      volModel: vol,
      weights: ModelWeights(),
      tracker: PerformanceTracker(),
    );
    return SignalEngine(
      dirModel: dir,
      returnModel: ret,
      volatilityModel: vol,
      ensemble: ens,
      settings: settings ?? const StrategySettings(),
    );
  }

  /// Minimum window size pentru predicții valide (from AiConfig)
  static int get kMinWindow => 64; // Match AiConfig.kWindow

  /// Predict complet - returnează Prediction? (null dacă date insuficiente)
  @override
  Future<Prediction?> predict(String symbol, List<Candle>? window) async {
    try {
      // Guard: check minimum data
      if (window == null || window.length < kMinWindow) {
        debugPrint(
            '⚠️ AI: not enough data for $symbol (got ${window?.length ?? 0}/$kMinWindow)');
        return null;
      }
      _lastWindow = window; // keep reference for decision filters
      List<double> probs;
      double expReturn;
      double vol;
      double conf;

      if (ensemble != null) {
        // Prefer ensemble if available
        final EnsembleResult er = await ensemble!.predict(window);
        probs = er.probs;
        expReturn = er.expReturn;
        // Optionally disable or soften volatility gating by blending with EWMA
        final ew = ewmaVol(window.map((c) => c.close).toList(), lambda: 0.94);
        vol = ((er.annVol.isFinite ? er.annVol : 0.0) * 0.7 +
                (ew.isFinite ? ew : 0.0) * 0.3)
            .clamp(0.01, 3.0);
        conf = er.confidence;
        if (kDebugMode) {
          debugPrint('🤝 Ensemble debug: ${er.debug}');
        }
      } else {
        // Fallback to single-model pipeline
        probs = await dirModel.predictProbs(window);
        expReturn = returnModel != null
            ? await returnModel!.predictReturn(window)
            : _fallbackReturn(window);
        vol = volatilityModel != null
            ? await volatilityModel!.predictVolatility(window)
            : _fallbackVolatility(window);
        conf = [probs[0], probs[1], probs[2]].reduce((a, b) => a > b ? a : b);
      }

      // Relative volume
      final rv = relativeVolume(window, period: 20);

      final pred = Prediction(
        symbol: symbol,
        asOf: window.last.time,
        pBuy: probs[0],
        pHold: probs[1],
        pSell: probs[2],
        expReturn: expReturn,
        annVol: vol,
        relVolume: rv,
      );

      // 🧪 DEBUG LOGS (shows prediction is actually running!)
      final action = decide(pred);
      final confPct = (pred.confidence() * 100).toStringAsFixed(1);
      final pBuyPct = (pred.pBuy * 100).toStringAsFixed(0);
      final pHoldPct = (pred.pHold * 100).toStringAsFixed(0);
      final pSellPct = (pred.pSell * 100).toStringAsFixed(0);
      final volPct = (pred.annVol * 100).toStringAsFixed(1);

      debugPrint('🤖 AI ➜ $symbol: $action conf=$confPct% '
          'p=[$pBuyPct $pHoldPct $pSellPct] vol=$volPct% '
          'ret=${(expReturn * 100).toStringAsFixed(2)}%');

      return pred;
    } catch (e, stackTrace) {
      debugPrint('❌ AI predict error for $symbol: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Decide action bazat pe reguli și thresholds
  @override
  String decide(Prediction p) {
    // Crypto-specific decision helpers
    bool strongUptrend(List<Candle> win) {
      final closes = win.map((c) => c.close).toList();
      final emaFast = ema(closes, 12);
      final emaSlow = ema(closes, 26);
      return emaFast.isFinite && emaSlow.isFinite && emaFast > emaSlow;
    }

    bool strongDowntrend(List<Candle> win) {
      final closes = win.map((c) => c.close).toList();
      final emaFast = ema(closes, 12);
      final emaSlow = ema(closes, 26);
      return emaFast.isFinite && emaSlow.isFinite && emaFast < emaSlow;
    }

    double rsi14(List<Candle> win) {
      final closes = win.map((c) => c.close).toList();
      return rsi(closes, period: 14);
    }

    // Primary: use direction probabilities (ignore HOLD probability)
    final double probBuy = p.pBuy;
    final double probSell = p.pSell;
    final double dirConf = probBuy > probSell ? probBuy : probSell;
    final double conf = p.confidence(volCap: settings.volCap);

    // Global gating: volatility cap and minimum confidence
    if (p.annVol > settings.volCap) return 'HOLD';
    if (dirConf < settings.confThresh || conf < settings.confThresh)
      return 'HOLD';

    // Expected return bias: avoid contrarian decisions
    final double er = p.expReturn; // fractional (e.g., 0.012 = +1.2%)
    const double dirMargin = 0.10; // 10% prob margin to override

    // If ER strongly positive, favor BUY unless SELL dominance is strong
    if (er >= settings.upThresh) {
      if (probBuy >= settings.confThresh) return 'BUY';
      if (probSell > probBuy && (probSell - probBuy) < dirMargin) return 'HOLD';
    }
    // If ER strongly negative, favor SELL unless BUY dominance is strong
    if (er <= settings.downThresh) {
      if (probSell >= settings.confThresh) return 'SELL';
      if (probBuy > probSell && (probBuy - probSell) < dirMargin) return 'HOLD';
    }

    // Directional choice with crypto filters
    if (probBuy > probSell) {
      // Boost BUY if trend and RSI confirm
      final okTrend = strongUptrend(_lastWindow ?? const []);
      final r = rsi14(_lastWindow ?? const []);
      if (okTrend || (r.isFinite && r < 65)) {
        return 'BUY';
      }
      // If overbought RSI>70, avoid chasing → HOLD
      if (r.isFinite && r > 70) return 'HOLD';
      return 'BUY';
    }
    if (probSell > probBuy) {
      final okTrend = strongDowntrend(_lastWindow ?? const []);
      final r = rsi14(_lastWindow ?? const []);
      if (okTrend || (r.isFinite && r > 35)) {
        return 'SELL';
      }
      // If oversold RSI<30, avoid panic selling → HOLD
      if (r.isFinite && r < 30) return 'HOLD';
      return 'SELL';
    }
    return 'HOLD';
  }

  /// Fallback return estimation (momentum-based)
  double _fallbackReturn(List<Candle> window) {
    final closes = window.map((c) => c.close).toList();
    if (closes.length < 5) return 0.0;

    // Simple momentum: average of last 5 returns
    final returns = <double>[];
    for (int i = closes.length - 5; i < closes.length - 1; i++) {
      returns.add((closes[i + 1] / closes[i]) - 1.0);
    }

    final avgReturn = returns.reduce((a, b) => a + b) / returns.length;
    return avgReturn.clamp(-0.05, 0.05);
  }

  /// Fallback volatility (EWMA)
  double _fallbackVolatility(List<Candle> window) {
    final closes = window.map((c) => c.close).toList();
    final vol = ewmaVol(closes, lambda: 0.94);
    return vol.isNaN ? 0.20 : vol.clamp(0.01, 3.0);
  }

  @override
  void dispose() {
    dirModel.dispose();
    returnModel?.dispose();
    volatilityModel?.dispose();
  }
}
