import 'entities.dart';

/// Generic predictor interface for on-device AI models.
/// Implementations should be pure and side-effect free (except internal caches).
abstract class AiPredictor {
  /// Predicts BUY/HOLD/SELL probabilities and auxiliary metrics for a symbol
  /// using the given OHLCV window at a specific timeframe (e.g., '5m','15m').
  /// Returns `Prediction` or null if model is unavailable or input is insufficient.
  Future<Prediction?> predict(
    String symbol,
    List<Candle> window, {
    required String timeframe,
  });
}
