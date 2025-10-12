import 'ai_predictor.dart';

class CoremlPatchTstPredictor implements AiPredictor {
  @override
  Future<Prediction?> predict(
    String symbol,
    List<List<double>> window, {
    required String timeframe,
  }) async {
    // Temporar: folosim TFLite pe toate platformele până legăm canalul CoreML.
    return null;
  }
}
