import 'package:flutter/foundation.dart';

import 'entities.dart';
import 'prediction_cache.dart';

/// IntelligentCacheManager wraps the existing PredictionCache and enforces
/// dynamic TTL + early invalidation based on market conditions.
///
/// Backward compatibility:
/// - Underlying PredictionCache remains the source of truth for storage
///   and static TTL. This manager overlays a stricter policy: it can
///   decide to ignore/replace a still-valid underlying entry.
class IntelligentCacheManager {
  final PredictionCache _cache;
  final DateTime Function() _now;

  /// Internal metadata stored per cache key for dynamic TTL and invalidation
  final Map<String, _Meta> _meta = {};

  // Counters for observability
  int hits = 0;
  int misses = 0;
  int invalidations = 0;

  IntelligentCacheManager(this._cache, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Compute dynamic TTL in seconds based on annualized volatility fraction
  /// e.g. 0.05 = 5% → 10s, 0.02..0.05 → 20s, < 0.02 → 30s
  Duration ttlForVol(double annVol) {
    final v = annVol.abs();
    if (v > 0.05) return const Duration(seconds: 10);
    if (v >= 0.02) return const Duration(seconds: 20);
    return const Duration(seconds: 30);
  }

  /// Returns cached prediction if both: underlying cache has it AND
  /// dynamic TTL and invalidation checks pass. Otherwise returns null.
  Prediction? get(
    String symbol,
    DateTime lastCandleTime, {
    required double latestClose,
    required double latestVolume,
    required double avgVolume,
    required double estAnnVol,
  }) {
    final key = _key(symbol, lastCandleTime);
    final pred = _cache.get(symbol, lastCandleTime);
    if (pred == null) {
      misses++;
      return null;
    }

    final meta = _meta[key];
    if (meta == null) {
      // No local metadata → treat as miss to avoid stale usage
      misses++;
      return null;
    }

    // Dynamic TTL based on volatility
    final ttl = ttlForVol(meta.annVol ?? estAnnVol);
    final age = _now().difference(meta.timestamp);
    if (age > ttl) {
      if (kDebugMode) {
        debugPrint('⏳ smart-cache expired ($age > $ttl) for $symbol');
      }
      invalidations++;
      return null;
    }

    // Early invalidation on price jump > 0.5%
    final base = meta.baseClose;
    if (base != null && base > 0) {
      final change = (latestClose - base).abs() / base;
      if (change > 0.005) {
        if (kDebugMode) {
          debugPrint(
              '⚡ smart-cache invalidation (price ${(change * 100).toStringAsFixed(2)}%) for $symbol');
        }
        invalidations++;
        return null;
      }
    }

    // Early invalidation on volume spike > 2x average
    if (avgVolume > 0 && latestVolume / avgVolume > 2.0) {
      if (kDebugMode) {
        debugPrint('📈 smart-cache invalidation (volume spike) for $symbol');
      }
      invalidations++;
      return null;
    }

    hits++;
    if (kDebugMode) debugPrint('💾 smart-cache HIT for $symbol');
    return pred;
  }

  /// Store prediction and attach metadata for future dynamic decisions.
  void put(
    String symbol,
    DateTime lastCandleTime,
    Prediction prediction, {
    required double baseClose,
    required double avgVolume,
    required double latestVolume,
    required double annVol,
  }) {
    final key = _key(symbol, lastCandleTime);
    // Use underlying cache with timeframe-aware TTL (best effort: use engine interval on prediction.asOf context)
    _cache.put(symbol, lastCandleTime, prediction);
    _meta[key] = _Meta(
      timestamp: _now(),
      baseClose: baseClose,
      avgVolume: avgVolume,
      latestVolume: latestVolume,
      annVol: annVol,
    );
    if (kDebugMode)
      debugPrint(
          '💾 smart-cache STORE for $symbol (ttl=${ttlForVol(annVol).inSeconds}s)');
  }

  void clearSymbol(String symbol) {
    _cache.clearSymbol(symbol);
    _meta.removeWhere((k, _) => k.startsWith('$symbol:'));
  }

  void clearAll() {
    _cache.clearAll();
    _meta.clear();
  }

  Map<String, dynamic> stats() => {
        'hits': hits,
        'misses': misses,
        'invalidations': invalidations,
        'entries': _meta.length,
      };

  String _key(String symbol, DateTime last) =>
      '$symbol:${last.millisecondsSinceEpoch}';
}

class _Meta {
  final DateTime timestamp;
  final double? baseClose;
  final double? avgVolume;
  final double? latestVolume;
  final double? annVol;

  _Meta({
    required this.timestamp,
    this.baseClose,
    this.avgVolume,
    this.latestVolume,
    this.annVol,
  });
}
