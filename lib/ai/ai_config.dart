/// AI Configuration - Constante centralizate pentru AI pipeline
class AiConfig {
  /// Determinism (global seed)
  static const int seed = 42;

  /// Decision thresholds (shared by ALL screens)
  static const double upThresh = 0.002; // +0.2%
  static const double downThresh = -0.002; // -0.2%
  static const double confThresh = 0.40; // 40% (more selective)
  static const double volCap =
      1.00; // 100% (relax cap to avoid over-filtering trades)
  // Ensemble/decision thresholds (ensure these exist)
  static const double probBuyThresh = 0.60;   // BUY if pBuy >= 0.60 (with gates)
  static const double probSellThresh = 0.60;  // SELL if pSell >= 0.60 (with gates)
  static const double minAbsRet = 0.0030;     // 0.30% minimum absolute expected return

  /// Additional global filters (optional usage by strategies/backtester)
  static const double minExpReturn = 0.015; // +1.5% minimum expected return
  static const double maxVolatility = 0.10; // 10% max annualized volatility

  /// Canonical feature policy (match PredictionRepo)
  static const String timeframe = '5m';
  static const int history =
      1000; // candles fetched (increase for better context)
  static const int window = 64; // rolling features window

  /// Cache TTL - cât timp păstrăm predicțiile în cache
  static const Duration cacheTtl = Duration(seconds: 20);

  /// Debug mode - mai multe logs
  static const bool kDebugMode = true;
  static const bool useVolModel =
      true; // allow disabling TFLite vol if unstable
  static const int volZeroDisableHits = 3; // consecutive zero hits to disable

  /// Optional: numerical invariants
  static const double maxFloatDrift = 1e-6; // FP16→F32 tolerance

  /// Model revision (for observability)
  static const String modelRev = "r1";

  /// Feature flags (runtime-togglable; single source of truth)
  static bool usePatchTst = true;          // enable PatchTST time-series predictor
  static bool useVisionVote = true;        // combine with vision predictor output if available
  static double visionWeight = 0.35;       // vision contribution in geometric voter (0..1)
  static bool useLegacyAiPanel = false;    // hide old confidence panel

  /// Force quote currency pentru Binance (USDT default)
  static const String kDefaultQuote = 'USDT';

  // Backward-compatible aliases for existing code
  static const String kInterval = timeframe;
  static const int kLimit = history;
  static const int kWindow = window;
}
