import 'package:flutter/foundation.dart';
import 'engine_interface.dart';
import 'entities.dart';
import 'ai_predictor.dart';
import 'ai_config.dart';

/// ISignalEngine adapter around an AiPredictor (PatchTST-lite backend)
class PatchTstEngine implements ISignalEngine {
  final AiPredictor predictor;
  String timeframe; // default TF used by repo when not specified

  PatchTstEngine(
      {required this.predictor, this.timeframe = AiConfig.timeframe});

  void setTimeframe(String tf) {
    timeframe = tf;
  }

  @override
  Future<Prediction?> predict(String symbol, List<Candle> window) async {
    try {
      final p = await predictor.predict(symbol, window, timeframe: timeframe);
      if (p == null) return null;
      // If predictor indicates missing model, propagate safe HOLD decision downstream
      if (p.reason == 'model_missing') {
        return Prediction(
          symbol: p.symbol,
          asOf: p.asOf,
          pBuy: 0.0,
          pHold: 1.0,
          pSell: 0.0,
          expReturn: 0.0,
          annVol: 0.0,
          relVolume: p.relVolume,
          reason: 'model_missing',
        );
      }
      return p;
    } catch (e, st) {
      debugPrint('❌ PatchTstEngine.predict error: $e\n$st');
      return null;
    }
  }

  @override
  String decide(Prediction p) {
    if (p.reason == 'model_missing') return 'HOLD';
    final probBuy = p.pBuy;
    final probSell = p.pSell;
    final er = p.expReturn; // fractional

    // Global gating
    if (p.annVol > AiConfig.volCap) return 'HOLD';

    // Threshold rules (use existing config fields)
    if (probBuy >= AiConfig.confThresh && er >= AiConfig.minExpReturn)
      return 'BUY';
    if (probSell >= AiConfig.confThresh && er <= -AiConfig.minExpReturn)
      return 'SELL';

    // Fallback to higher of probs if confidence strong
    final dirConf = probBuy > probSell ? probBuy : probSell;
    if (dirConf >= (AiConfig.confThresh)) {
      return probBuy >= probSell ? 'BUY' : 'SELL';
    }
    return 'HOLD';
  }

  @override
  void dispose() {}
}
