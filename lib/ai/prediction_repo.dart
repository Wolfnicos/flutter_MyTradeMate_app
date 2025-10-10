import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'ai_locator.dart';
import 'ai_config.dart';
import 'prediction_cache.dart';
import 'intelligent_cache.dart';
import '../services/ohlcv_service.dart';
import '../services/symbol_mapper.dart';

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
          debugPrint('⚠️ Not enough candles for $uiSymbol: ${candles.length}/${AiConfig.kWindow}');
        }
        return null;
      }
      
      // Smart cache lookup (dynamic TTL & early invalidation)
      final lastCandleTime = candles.last.time;
      final latestClose = candles.last.close;
      final avgVolume = candles.length >= 20
          ? candles.sublist(candles.length - 20).map((c) => c.volume).reduce((a, b) => a + b) / 20
          : candles.map((c) => c.volume).reduce((a, b) => a + b) / candles.length;
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
        if (AiConfig.kDebugMode) debugPrint('💾 Repo: smart-cache HIT for $feedSymbol');
        return smart;
      }
      
      // Predict cu AI engine (direct access)
      final prediction = await AILocator.I.engine.predict(feedSymbol, candles);
      
      if (prediction == null) {
        if (AiConfig.kDebugMode) {
          debugPrint('⚠️ Prediction failed for $uiSymbol');
        }
        return null;
      }
      
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
      
      // Single consolidated log per symbol
      final action = AILocator.I.decide(prediction);
      final conf = (prediction.confidence() * 100).toStringAsFixed(1);
      final ret = (prediction.expReturn * 100).toStringAsFixed(2);
      final vol = (prediction.annVol * 100).toStringAsFixed(1);
      
      debugPrint('🤖 AI ➜ $uiSymbol: action=$action conf=$conf% ret=$ret% vol=$vol%');
      
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
  
  /// Fetch a fresh prediction for a given UI symbol and interval, falling back to cache if valid.
  /// Returns null if AI not initialized or insufficient data.
  Future<Prediction?> getOrFetch({
    required String symbol,
    String interval = '5m',
    int? limit,
  }) async {
    try {
      if (!AILocator.I.isInitialized) {
        if (AiConfig.kDebugMode) debugPrint('⚠️ AI not initialized for $symbol');
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
          debugPrint('⚠️ Not enough candles for $symbol: ${candles.length}/${AiConfig.kWindow}');
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
          : candles.map((c) => c.volume).reduce((a, b) => a + b) / candles.length;
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
        if (AiConfig.kDebugMode) debugPrint('💾 Repo: smart-cache HIT for $feedSymbol');
        return smart;
      }

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
        debugPrint('🤖 AI (fresh) ➜ $symbol@$interval: action=$action conf=$conf% ret=$ret% vol=$vol%');
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

