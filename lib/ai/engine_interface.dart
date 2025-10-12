import 'entities.dart';

/// Minimal engine interface to enable deterministic testing and DI.
abstract class ISignalEngine {
  Future<Prediction?> predict(String symbol, List<Candle> window);
  String decide(Prediction p);
  void dispose();
}
