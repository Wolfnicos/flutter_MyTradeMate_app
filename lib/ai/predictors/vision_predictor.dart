import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class VisionPredictor {
  static const String modelAsset = 'assets/models/vision_fp16.tflite';
  Interpreter? _interp;

  Future<void> _ensure() async {
    if (_interp != null) return;
    _interp = await Interpreter.fromAsset(modelAsset);
    // ignore: avoid_print
    print('[V-Model] loaded: assets/models/vision_fp16.tflite');
  }

  Float32List _toFloatRgb(img.Image im) {
    final resized = img.copyResize(im, width: 224, height: 224);
    final rgba = resized.getBytes(); // RGBA (4 channels)
    final out = Float32List(224 * 224 * 3);
    int j = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i] / 255.0;
      final g = rgba[i + 1] / 255.0;
      final b = rgba[i + 2] / 255.0;
      out[j++] = r;
      out[j++] = g;
      out[j++] = b;
    }
    return out;
  }

  Future<List<double>> predictFromAsset(String assetPath) async {
    final b = await rootBundle.load(assetPath);
    return predictChartImage(b.buffer.asUint8List());
  }

  /// Predicts [pBuy, pHold, pSell] from a chart image bytes (PNG/JPEG).
  Future<List<double>> predictChartImage(Uint8List bytes) async {
    await _ensure();
    final im = img.decodeImage(bytes);
    if (im == null) {
      throw Exception('decode failed');
    }
    final floats = _toFloatRgb(im);

    int idx = 0;
    final input = List.generate(
        1,
        (_) => List.generate(
            224,
            (_) => List.generate(224, (_) {
                  final r = floats[idx++], g = floats[idx++], b = floats[idx++];
                  return [r, g, b];
                })));

    final output = [List.filled(3, 0.0)];
    _interp!.run(input, output);
    return (output[0] as List).cast<double>();
  }

  void close() {
    _interp?.close();
    _interp = null;
  }
}
