import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'ai_locator.dart';
import 'ai_config.dart';
import 'prediction_cache.dart';
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
  
  PredictionRepo(this.ohlcvService);
  
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
      
      // Check cache first
      final lastCandleTime = candles.last.time;
      final cached = _cache.get(feedSymbol, lastCandleTime);
      if (cached != null) {
        return cached; // Cache HIT!
      }
      
      // Predict cu AI engine (direct access)
      final prediction = await AILocator.I.engine.predict(feedSymbol, candles);
      
      if (prediction == null) {
        if (AiConfig.kDebugMode) {
          debugPrint('⚠️ Prediction failed for $uiSymbol');
        }
        return null;
      }
      
      // Cache result
      _cache.put(feedSymbol, lastCandleTime, prediction);
      
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

