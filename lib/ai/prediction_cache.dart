import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'ai_config.dart';

/// Cache entry cu timestamp pentru TTL
class _CacheEntry {
  final Prediction prediction;
  final DateTime timestamp;

  _CacheEntry(this.prediction, this.timestamp);

  bool isExpired() {
    return DateTime.now().difference(timestamp) > AiConfig.cacheTtl;
  }
}

/// PredictionCache - Cache simplu cu TTL pentru predicții AI
/// Key format: "SYMBOL:lastCandleTimestamp"
class PredictionCache {
  final Map<String, _CacheEntry> _cache = {};

  /// Get prediction from cache (null dacă expirat sau lipsă)
  Prediction? get(String symbol, DateTime lastCandleTime) {
    final key = _buildKey(symbol, lastCandleTime);
    final entry = _cache[key];

    if (entry == null) return null;

    if (entry.isExpired()) {
      _cache.remove(key);
      if (AiConfig.kDebugMode) {
        debugPrint('🗑️ Cache expired for $symbol');
      }
      return null;
    }

    if (AiConfig.kDebugMode) {
      debugPrint('💾 Cache HIT for $symbol');
    }
    return entry.prediction;
  }

  /// Put prediction în cache
  void put(String symbol, DateTime lastCandleTime, Prediction prediction) {
    final key = _buildKey(symbol, lastCandleTime);
    _cache[key] = _CacheEntry(prediction, DateTime.now());

    if (AiConfig.kDebugMode) {
      debugPrint('💾 Cache STORED for $symbol');
    }
  }

  /// Clear cache pentru un symbol specific
  void clearSymbol(String symbol) {
    _cache.removeWhere((key, _) => key.startsWith('$symbol:'));
  }

  /// Clear tot cache-ul
  void clearAll() {
    _cache.clear();
    debugPrint('🗑️ Cache cleared');
  }

  /// Build cache key
  String _buildKey(String symbol, DateTime lastCandleTime) {
    return '$symbol:${lastCandleTime.millisecondsSinceEpoch}';
  }

  /// Get cache stats (pentru debugging)
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final expired = _cache.values.where((e) => e.isExpired()).length;
    final valid = _cache.length - expired;

    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
    };
  }
}
