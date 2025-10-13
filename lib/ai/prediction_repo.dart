import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'ai_locator.dart';
import 'ai_config.dart';
import 'prediction_cache.dart';
import 'intelligent_cache.dart';
import '../services/ohlcv_service.dart';
import '../services/symbol_mapper.dart';
import 'strategies/hybrid_strategies.dart' as hs;
import 'package:mytrademate/src/core/trading_prefs.dart';
import 'dart:math' as math;
import '../vision/chart_capture_service.dart';
import 'vision_predictor.dart';
import 'ensemble/ensemble_voter.dart';

/// PredictionRepo - Repository pattern pentru predicții AI
/// - Centralizează accesul la predicții
/// - Cache cu TTL
/// - Null-safe
/// - Symbol mapping
/// - Error handling
class PredictionRepo {
  final OHLCVService ohlcvService;
  final PredictionCache _cache = PredictionCache();
  late final IntelligentCacheManager _smartCache;
  final Map<String, String> _hybridAction = {};
  final Map<String, List<double>> _lastVisionProbs = {};

  PredictionRepo(this.ohlcvService) {
    _smartCache = IntelligentCacheManager(_cache);
  }

  /// Get prediction pentru un UI symbol (ex: 'BTC/EUR', 'BTCUSDT', etc.)
  /// Returns null dacă:
  /// - AI not initialized
  /// - Not enough data
  /// - Error occurred
  ///
  /// Never throws! Always safe to call.
  Future<Prediction?> getFor(String uiSymbol) async {
    try {
      // Check AI initialized
      if (!AILocator.I.isInitialized) {
        if (AiConfig.kDebugMode) {
          debugPrint('⚠️ AI not initialized for $uiSymbol');
        }
        return null;
      }

      // Map UI symbol → feed symbol (force USDT pentru Binance)
      final feedSymbol = SymbolMapper.mapUiToFeed(
        uiSymbol,
        quote: AiConfig.kDefaultQuote,
      );

      // Fetch OHLCV data
      final candles = await ohlcvService.fetchCandles(
        feedSymbol,
        interval: AiConfig.kInterval,
        limit: AiConfig.kLimit,
        forceQuote: true,
      );

      // Check minimum data
      if (candles.length < AiConfig.kWindow) {
        if (AiConfig.kDebugMode) {
          debugPrint(
              '⚠️ Not enough candles for $uiSymbol: ${candles.length}/${AiConfig.kWindow}');
        }
        return null;
      }

      // Smart cache lookup (dynamic TTL & early invalidation)
      final lastCandleTime = candles.last.time;
      final latestClose = candles.last.close;
      final avgVolume = candles.length >= 20
          ? candles
                  .sublist(candles.length - 20)
                  .map((c) => c.volume)
                  .reduce((a, b) => a + b) /
              20
          : candles.map((c) => c.volume).reduce((a, b) => a + b) /
              candles.length;
      final latestVolume = candles.last.volume;
      // We don't know annVol yet; pass 0 and let manager use meta if any
      final smart = _smartCache.get(
        feedSymbol,
        lastCandleTime,
        latestClose: latestClose,
        latestVolume: latestVolume,
        avgVolume: avgVolume,
        estAnnVol: 0.0,
      );
      if (smart != null) {
        if (AiConfig.kDebugMode)
          debugPrint('💾 Repo: smart-cache HIT for $feedSymbol');
        return smart;
      }

      // Multi-timeframe TS predictions + weighted geometric mean across TFs
      final Map<String, List<double>> tfProbs = {};
      final Map<String, double> tfExp = {};
      final Map<String, double> tfVol = {};
      Prediction? primaryPred;
      final Map<String, Prediction> tfPreds = {};
      for (final tf in AiConfig.enabledTimeframes) {
        try {
          // Per-timeframe fetch with a generous limit to avoid identical inputs
          final tfCandles = tf == AiConfig.kInterval
              ? candles
              : await ohlcvService.fetchCandles(
                  feedSymbol,
                  interval: tf,
                  limit: 2000,
                  forceQuote: true,
                );
          if (tfCandles.length < AiConfig.kWindow) continue;
          try {
            // ignore: avoid_dynamic_calls
            (AILocator.I.engine as dynamic).setTimeframe?.call(tf);
          } catch (_) {}
          final p = await AILocator.I.engine.predict(feedSymbol, tfCandles);
          if (p == null) continue;
          if (tf == AiConfig.kInterval) primaryPred = p;
          tfProbs[tf] = [p.pBuy, p.pHold, p.pSell];
          tfPreds[tf] = p;
          tfExp[tf] = p.expReturn;
          tfVol[tf] = p.annVol;
        } catch (_) {}
      }
      if (tfProbs.isEmpty || primaryPred == null) {
        if (AiConfig.kDebugMode) debugPrint('⚠️ TS predictions missing for $uiSymbol');
        return null;
      }
      // Weighted geometric mean across TFs
      List<double> tfVote(List<double> a, List<double> b, double wa, double wb) {
        final r = <double>[];
        for (int i = 0; i < a.length; i++) {
          final v = math.pow(a[i].clamp(1e-6, 1.0), wa) * math.pow(b[i].clamp(1e-6, 1.0), wb);
          r.add(v.toDouble());
        }
        final s = r.fold<double>(0.0, (p, c) => p + c);
        return r.map((e) => e / (s == 0 ? 1.0 : s)).toList();
      }
      List<double>? agg;
      // Sort TFs in a stable order based on weights (desc)
      final entries = tfProbs.entries.toList()
        ..sort((a, b) => (AiConfig.tfWeights[b.key] ?? 1.0).compareTo(AiConfig.tfWeights[a.key] ?? 1.0));
      for (final e in entries) {
        final w = AiConfig.tfWeights[e.key] ?? 1.0;
        if (agg == null) {
          // start with current tf raised to its weight
          final base = e.value.map((x) => math.pow(x.clamp(1e-6, 1.0), w).toDouble()).toList();
          final sum = base.fold<double>(0.0, (p, c) => p + c);
          agg = base.map((v) => v / (sum == 0 ? 1.0 : sum)).toList();
        } else {
          agg = tfVote(agg!, e.value, 1.0, w);
        }
      }
      if (AiConfig.kDebugMode) {
        debugPrint('[TF-Vote] $feedSymbol probs per TF: ${tfProbs.map((k,v)=>MapEntry(k, v.map((e)=>e.toStringAsFixed(3)).toList()))}');
      }
      var finalProbs = agg!;

      // Optional: Vision vote (geometric mean) if enabled and prediction available
      if (AiConfig.useVisionVote) {
        try {
          final cap = await ChartCaptureService.renderCandlesImage(candles: candles);
          await VisionPredictor.I.ensureLoaded();
          final vProbs = await VisionPredictor.I.predictProbsRGB(
            rgbBytes: cap.bytes,
            width: cap.width,
            height: cap.height,
          );
          // Guard: ignore Vision if output has too little diversity
          final maxP = vProbs.reduce((a,b)=> a>b? a:b);
          final minP = vProbs.reduce((a,b)=> a<b? a:b);
          final meanP = (vProbs[0]+vProbs[1]+vProbs[2]) / 3.0;
          double variance = 0.0; for (final p in vProbs) { variance += (p-meanP)*(p-meanP); }
          variance /= 3.0;
          double localW = AiConfig.visionWeight.clamp(0.0, 1.0);
          bool lowDiversityWithinVector = (variance < 1e-3) || ((maxP - minP) < 0.02);
          // Temporal diversity guard: compare with last vProbs for this symbol
          final last = _lastVisionProbs[feedSymbol];
          bool lowChangeSinceLast = false;
          if (last != null && last.length == vProbs.length) {
            double diffSum = 0.0; for (int i = 0; i < vProbs.length; i++) { diffSum += (vProbs[i] - last[i]).abs(); }
            lowChangeSinceLast = diffSum < 0.01; // ~1% total change across classes
          }
          if (lowDiversityWithinVector || lowChangeSinceLast) {
            if (AiConfig.kDebugMode) {
              debugPrint('[Vision-Guard] Ignoring Vision (var=${variance.toStringAsFixed(4)}, range=${(maxP-minP).toStringAsFixed(3)}, Δprev=${lowChangeSinceLast ? 'low' : 'ok'})');
            }
            localW = 0.0;
          }
          final w = localW;
          List<double> mix(List<double> a, List<double> b) {
            final r = <double>[];
            for (var i = 0; i < a.length; i++) {
              final g = math.pow(a[i].clamp(1e-6, 1.0), (1.0 - w)) *
                  math.pow(b[i].clamp(1e-6, 1.0), w);
              r.add(g.toDouble());
            }
            final s = r.fold<double>(0.0, (p, c) => p + c);
            return r.map((e) => e / (s == 0 ? 1.0 : s)).toList();
          }
          final probs = mix(finalProbs, vProbs);
          // ignore: avoid_print
          print('[Ensemble] probs: pBuy=${probs[0].toStringAsFixed(3)}, pHold=${probs[1].toStringAsFixed(3)}, pSell=${probs[2].toStringAsFixed(3)}  (visionWeight=$w)');
          finalProbs = probs;
          _lastVisionProbs[feedSymbol] = vProbs;
        } catch (_) {
          // best-effort only
        }
      }

      // Build final prediction using primary TF expReturn/annVol and ensemble probs
      // Weighted metrics across TFs (for confidence variability)
      double wSum = 0.0, retSum = 0.0, volSum = 0.0;
      tfPreds.forEach((tf, p) {
        final w = AiConfig.tfWeights[tf] ?? 1.0;
        wSum += w;
        retSum += w * p.expReturn;
        volSum += w * p.annVol;
      });
      final expRetW = wSum == 0 ? primaryPred!.expReturn : (retSum / wSum);
      final annVolW = wSum == 0 ? primaryPred!.annVol : (volSum / wSum);

      var prediction = Prediction(
        symbol: primaryPred!.symbol,
        asOf: primaryPred.asOf,
        pBuy: finalProbs[0],
        pHold: finalProbs[1],
        pSell: finalProbs[2],
        expReturn: expRetW,
        annVol: annVolW,
        relVolume: primaryPred.relVolume,
        tsProbs: agg,
        visionProbs: AiConfig.useVisionVote ? _lastVisionProbs[feedSymbol] : null,
        perTfProbs: tfProbs,
        perTfExpRet: tfExp,
        perTfAnnVol: tfVol,
      );

      // Cache result + smart metadata (needs annVol + volumes)
      _smartCache.put(
        feedSymbol,
        lastCandleTime,
        prediction,
        baseClose: latestClose,
        avgVolume: avgVolume,
        latestVolume: latestVolume,
        annVol: prediction.annVol,
      );

      // If default strategy is hybrid, compute hybrid action and store for decide()
      try {
        final prefs = await TradingPrefs.load();
        final strategy = prefs.getDefaultStrategy();
        if (strategy.startsWith('hybrid')) {
          // Load required timeframes
          final needs15m = strategy == 'hybrid3';
          final needs1h = strategy == 'hybrid2' || strategy == 'hybrid4';
          final needs4h = strategy == 'hybrid1' ||
              strategy == 'hybrid3' ||
              strategy == 'hybrid5';
          final needs5m = strategy != 'hybrid3';
          const needs1d = true;
          final tf5m = needs5m
              ? await ohlcvService.fetchCandles(feedSymbol,
                  interval: '5m', limit: 2000)
              : <Candle>[];
          final tf15m = needs15m
              ? await ohlcvService.fetchCandles(feedSymbol,
                  interval: '15m', limit: 2000)
              : <Candle>[];
          final tf1h = needs1h
              ? await ohlcvService.fetchCandles(feedSymbol,
                  interval: '1h', limit: 2000)
              : <Candle>[];
          final tf4h = needs4h
              ? await ohlcvService.fetchCandles(feedSymbol,
                  interval: '4h', limit: 2000)
              : <Candle>[];
          final tf1d = needs1d
              ? await ohlcvService.fetchCandles(feedSymbol,
                  interval: '1d', limit: 2000)
              : <Candle>[];
          Map<String, dynamic> res;
          switch (strategy) {
            case 'hybrid1':
              res = hs.hybridStrategy1(tf5m: tf5m, tf4h: tf4h, tf1d: tf1d);
              break;
            case 'hybrid2':
              res = hs.hybridStrategy2(tf5m: tf5m, tf1h: tf1h, tf1d: tf1d);
              break;
            case 'hybrid3':
              res = hs.hybridStrategy3(tf15m: tf15m, tf4h: tf4h, tf1d: tf1d);
              break;
            case 'hybrid4':
              res = hs.hybridStrategy4(tf5m: tf5m, tf1h: tf1h, tf1d: tf1d);
              break;
            case 'hybrid5':
              res = hs.hybridStrategy5(tf5m: tf5m, tf4h: tf4h, tf1d: tf1d);
              break;
            default:
              res = const {'action': 'HOLD'};
          }
          final action = (res['action'] ?? 'HOLD') as String;
          final key = _hyKey(prediction.symbol, prediction.asOf);
          _hybridAction[key] = action;
        }
      } catch (_) {
        // ignore hybrid computation errors
      }

      // Single consolidated log per symbol
      final action = AILocator.I.decide(prediction);
      final conf = (prediction.confidence() * 100).toStringAsFixed(1);
      final ret = (prediction.expReturn * 100).toStringAsFixed(2);
      final vol = (prediction.annVol * 100).toStringAsFixed(1);

      debugPrint(
          '🤖 AI ➜ $uiSymbol: action=$action conf=$conf% ret=$ret% vol=$vol%');

      return prediction;
    } catch (e, st) {
      // Never throw! Just log and return null
      debugPrint('❌ PredictionRepo error for $uiSymbol: $e');
      if (AiConfig.kDebugMode) {
        debugPrint('Stack: $st');
      }
      return null;
    }
  }

  String _hyKey(String symbol, DateTime asOf) =>
      '${symbol.toUpperCase()}@${asOf.millisecondsSinceEpoch}';

  String? hybridActionFor(Prediction p) {
    return _hybridAction[_hyKey(p.symbol, p.asOf)];
  }

  /// Fetch a fresh prediction for a given UI symbol and interval, falling back to cache if valid.
  /// Returns null if AI not initialized or insufficient data.
  Future<Prediction?> getOrFetch({
    required String symbol,
    String interval = '5m',
    int? limit,
  }) async {
    try {
      if (!AILocator.I.isInitialized) {
        if (AiConfig.kDebugMode)
          debugPrint('⚠️ AI not initialized for $symbol');
        return null;
      }

      final feedSymbol = SymbolMapper.mapUiToFeed(
        symbol,
        quote: AiConfig.kDefaultQuote,
      );

      final candles = await ohlcvService.fetchCandles(
        feedSymbol,
        interval: interval,
        limit: limit ?? AiConfig.kLimit,
        forceQuote: true,
      );

      if (candles.length < AiConfig.kWindow) {
        if (AiConfig.kDebugMode) {
          debugPrint(
              '⚠️ Not enough candles for $symbol: ${candles.length}/${AiConfig.kWindow}');
        }
        return null;
      }

      final lastCandleTime = candles.last.time;
      final latestClose = candles.last.close;
      final avgVolume = candles.length >= 20
          ? candles
                  .sublist(candles.length - 20)
                  .map((c) => c.volume)
                  .reduce((a, b) => a + b) /
              20
          : candles.map((c) => c.volume).reduce((a, b) => a + b) /
              candles.length;
      final latestVolume = candles.last.volume;

      final smart = _smartCache.get(
        feedSymbol,
        lastCandleTime,
        latestClose: latestClose,
        latestVolume: latestVolume,
        avgVolume: avgVolume,
        estAnnVol: 0.0,
      );
      if (smart != null) {
        if (AiConfig.kDebugMode)
          debugPrint('💾 Repo: smart-cache HIT for $feedSymbol');
        return smart;
      }

      // Pass timeframe context via engine’s default TF in PatchTstEngine.
      // For multi-TF models, repo interval will be used by OHLCVService and engine logic.
      final prediction = await AILocator.I.engine.predict(feedSymbol, candles);
      if (prediction == null) return null;

      _smartCache.put(
        feedSymbol,
        lastCandleTime,
        prediction,
        baseClose: latestClose,
        avgVolume: avgVolume,
        latestVolume: latestVolume,
        annVol: prediction.annVol,
      );

      if (AiConfig.kDebugMode) {
        final action = AILocator.I.decide(prediction);
        final conf = (prediction.confidence() * 100).toStringAsFixed(1);
        final ret = (prediction.expReturn * 100).toStringAsFixed(2);
        final vol = (prediction.annVol * 100).toStringAsFixed(1);
        debugPrint(
            '🤖 AI (fresh) ➜ $symbol@$interval: action=$action conf=$conf% ret=$ret% vol=$vol% rev=${AiConfig.modelRev}');
      }

      return prediction;
    } catch (e, st) {
      debugPrint('❌ PredictionRepo.getOrFetch error for $symbol@$interval: $e');
      if (AiConfig.kDebugMode) debugPrint('Stack: $st');
      return null;
    }
  }

  /// Clear cache pentru un symbol
  void clearCache(String symbol) {
    _cache.clearSymbol(symbol);
  }

  /// Clear tot cache-ul
  void clearAllCache() {
    _cache.clearAll();
  }

  /// Get cache stats (debugging)
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }
}
