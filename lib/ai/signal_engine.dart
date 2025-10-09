import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'engine_interface.dart';
import 'models/direction_model.dart';
import 'models/return_model.dart';
import 'models/volatility_model.dart';
import 'indicators.dart';

/// SignalEngine - Core ML pipeline pentru trading signals
/// Combină 3 modele: Direction, Return, Volatility
class SignalEngine implements ISignalEngine {
  final DirectionModel dirModel;
  final ReturnModel? returnModel;
  final VolatilityModel? volatilityModel;
  final StrategySettings settings;

  SignalEngine({
    required this.dirModel,
    this.returnModel,
    this.volatilityModel,
    this.settings = const StrategySettings(),
  });

  /// Factory cu toate modelele
  factory SignalEngine.full({StrategySettings? settings}) {
    return SignalEngine(
      dirModel: DirectionModel(),
      returnModel: ReturnModel(),
      volatilityModel: VolatilityModel(),
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
        debugPrint('⚠️ AI: not enough data for $symbol (got ${window?.length ?? 0}/$kMinWindow)');
        return null;
      }
    // Direction probabilities (BUY/HOLD/SELL)
    final probs = await dirModel.predictProbs(window);
    
    // Expected return
    final expReturn = returnModel != null
        ? await returnModel!.predictReturn(window)
        : _fallbackReturn(window);
    
    // Volatility
    final vol = volatilityModel != null
        ? await volatilityModel!.predictVolatility(window)
        : _fallbackVolatility(window);
    
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
      final conf = (pred.confidence() * 100).toStringAsFixed(1);
      final pBuyPct = (pred.pBuy * 100).toStringAsFixed(0);
      final pHoldPct = (pred.pHold * 100).toStringAsFixed(0);
      final pSellPct = (pred.pSell * 100).toStringAsFixed(0);
      final volPct = (pred.annVol * 100).toStringAsFixed(1);
      
      debugPrint('🤖 AI ➜ $symbol: $action conf=$conf% '
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
    final conf = p.confidence(volCap: settings.volCap);
    
    // Rule 1: BUY conditions
    // - Expected return > upThresh
    // - pBUY > confThresh
    // - Confidence > confThresh
    // - Volatility < volCap
    if (p.expReturn >= settings.upThresh &&
        p.pBuy >= settings.confThresh &&
        conf >= settings.confThresh &&
        p.annVol <= settings.volCap) {
      return 'BUY';
    }
    
    // Rule 2: SELL conditions
    // - Expected return < downThresh (negative)
    // - pSELL > confThresh
    // - Confidence > confThresh
    // - Volatility < volCap
    if (p.expReturn <= settings.downThresh &&
        p.pSell >= settings.confThresh &&
        conf >= settings.confThresh &&
        p.annVol <= settings.volCap) {
      return 'SELL';
    }
    
    // Rule 3: Default HOLD
    // - Conditions not met
    // - High volatility (risky)
    // - Low confidence
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

