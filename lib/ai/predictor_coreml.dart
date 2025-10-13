import 'ai_predictor.dart';
import 'entities.dart';

class CoremlPatchTstPredictor implements AiPredictor {
  @override
  Future<Prediction?> predict(
    String symbol,
    List<Candle> window, {
    required String timeframe,
  }) async {
    // Temporar: folosim TFLite pe toate platformele până legăm canalul CoreML.
    return null;
  }
}
