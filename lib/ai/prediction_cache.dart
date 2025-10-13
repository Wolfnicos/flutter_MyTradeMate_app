import 'package:flutter/foundation.dart';
import 'entities.dart';
import 'ai_config.dart';

/// Cache entry cu timestamp pentru TTL
class _CacheEntry {
  final Prediction prediction;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry(this.prediction, this.timestamp, this.ttl);

  bool isExpired() {
    return DateTime.now().difference(timestamp) > ttl;
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
  void put(String symbol, DateTime lastCandleTime, Prediction prediction, {String timeframe = '5m'}) {
    final key = _buildKey(symbol, lastCandleTime);
    final ttl = _ttlFor(timeframe);
    _cache[key] = _CacheEntry(prediction, DateTime.now(), ttl);

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

  Duration _ttlFor(String tf) {
    switch (tf) {
      case '5m':
        return const Duration(seconds: 30);
      case '15m':
        return const Duration(minutes: 2);
      case '1h':
        return const Duration(minutes: 10);
      case '4h':
        return const Duration(minutes: 30);
      case '1d':
        return const Duration(hours: 2);
      default:
        return const Duration(seconds: 30);
    }
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
