/// AI Configuration - Constante centralizate pentru AI pipeline
class AiConfig {
  /// Determinism (global seed)
  static const int seed = 42;

  /// Decision thresholds (shared by ALL screens)
  static const double upThresh = 0.003;      // +0.3%
  static const double downThresh = -0.003;   // -0.3%
  static const double confThresh = 0.60;     // 60%

  /// Canonical feature policy (match PredictionRepo)
  static const String timeframe = '5m';
  static const int history = 100; // candles fetched
  static const int window = 64;   // rolling features window

  /// Cache TTL - cât timp păstrăm predicțiile în cache
  static const Duration cacheTtl = Duration(seconds: 20);
  
  /// Debug mode - mai multe logs
  static const bool kDebugMode = true;

  /// Optional: numerical invariants
  static const double maxFloatDrift = 1e-6; // FP16→F32 tolerance

  /// Force quote currency pentru Binance (USDT default)
  static const String kDefaultQuote = 'USDT';

  // Backward-compatible aliases for existing code
  static const String kInterval = timeframe;
  static const int kLimit = history;
  static const int kWindow = window;
}

