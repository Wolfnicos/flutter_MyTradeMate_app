import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/predictors/vision_predictor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Vision predictor smoke: 3 finite probabilities', () async {
    final model = File('assets/models/vision_fp16.tflite');
    if (!model.existsSync()) return;
    await VisionPredictor.I.ensureLoaded();
    final width = 16, height = 16;
    final rgb = List<int>.filled(width * height * 3, 0);
    for (int i = 0; i < rgb.length; i += 3) {
      rgb[i] = 255;
    }
    final bytes = Uint8List.fromList(rgb);
    final probs = await VisionPredictor.I
        .predictProbsRGB(rgbBytes: bytes, width: width, height: height);
    expect(probs.length, 3);
    expect(probs[0].isFinite, isTrue);
    expect(probs[1].isFinite, isTrue);
    expect(probs[2].isFinite, isTrue);
  });

  test('Vision assets presence', () {
    final model = File('assets/models/vision_fp16.tflite');
    final probe = File('assets/images/chart_probe.png');
    if (!model.existsSync() || !probe.existsSync()) {
      // ignore: avoid_print
      print('⚠️ Vision assets missing -> skipping');
      return;
    }
    expect(model.lengthSync() > 0, true);
    expect(probe.lengthSync() > 0, true);
  });
}
