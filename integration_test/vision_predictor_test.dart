import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:integration_test/integration_test.dart';
import 'package:mytrademate/ai/predictors/vision_predictor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Vision predictor smoke if assets exist', (tester) async {
    final modelPath = 'assets/models/vision_fp16.tflite';
    final imagePath = 'assets/images/chart_probe.png';
    final hasModel = File(modelPath).existsSync();
    final hasImage = File(imagePath).existsSync();
    if (!hasModel || !hasImage) {
      return; // skip if assets not present in CI
    }

    final bytes = (await rootBundle.load(imagePath)).buffer.asUint8List();
    final vp = VisionPredictor();
    final probs = await vp.predictChartImage(bytes);
    expect(probs.length, 3);
    expect(probs[0].isFinite, isTrue);
    expect(probs[1].isFinite, isTrue);
    expect(probs[2].isFinite, isTrue);
  });
}



