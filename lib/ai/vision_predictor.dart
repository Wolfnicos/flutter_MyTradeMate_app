import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// VisionPredictor - singleton TFLite runtime for chart image classification.
/// Loads assets/models/vision_fp16.tflite once and predicts [pBuy,pHold,pSell].
class VisionPredictor {
  VisionPredictor._();
  static final VisionPredictor I = VisionPredictor._();

  tfl.Interpreter? _interp;
  bool _expectsFloat01 = true; // infer from model input type on load

  Future<void> ensureLoaded() async {
    if (_interp != null) return;
    final it = await tfl.Interpreter.fromAsset('assets/models/vision_fp16.tflite');
    _interp = it;
    // ignore: avoid_print
    print('[V-Model] loaded: assets/models/vision_fp16.tflite');
    try {
      final t = it.getInputTensor(0);
      final typeName = t.type.toString().toLowerCase();
      _expectsFloat01 = typeName.contains('float');
    } catch (_) {
      _expectsFloat01 = true;
    }
  }

  /// Accepts RGB bytes HxW and runs Vision -> returns (pBuy,pHold,pSell) normalized.
  Future<List<double>> predictProbsRGB({
    required Uint8List rgbBytes,
    required int width,
    required int height,
  }) async {
    await ensureLoaded();
    final it = _interp!;

    // Debug: image hash and size
    int imageHash = 0;
    for (final b in rgbBytes) { imageHash = (imageHash + b) & 0x7fffffff; }
    // ignore: avoid_print
    print('[Vision-Debug] Image hash: $imageHash, size: ${rgbBytes.length}, WxH: ${width}x$height');

    // Build NHWC input [1,H,W,3]
    int idx = 0;
    final input = List.generate(1, (_) =>
      List.generate(height, (_) =>
        List.generate(width, (_) {
          final r = rgbBytes[idx++].toDouble();
          final g = rgbBytes[idx++].toDouble();
          final b = rgbBytes[idx++].toDouble();
          if (_expectsFloat01) {
            return [r / 255.0, g / 255.0, b / 255.0];
          }
          return [r, g, b];
        })
      )
    );

    // Prepare output [1,3] or [3]
    final out = [List.filled(3, 0.0)];
    final t0 = DateTime.now();
    try {
      it.run(input, out);
    } catch (_) {
      // Retry shape fallback as [3]
      final alt = List.filled(3, 0.0);
      it.run(input, alt);
      out[0] = alt;
    }
    final dtMs = DateTime.now().difference(t0).inMilliseconds;

    // Flatten and normalize
    final raw = (out[0] as List).map((e) => (e as num).toDouble()).toList(growable: false);
    List<double> probs;
    final sum = raw.fold<double>(0.0, (a, b) => a + b);
    if (sum > 0.0 && (sum - 1.0).abs() < 1e-3) {
      probs = raw;
    } else {
      final mx = raw.reduce((a, b) => a > b ? a : b);
      final exps = raw.map((x) => math.exp(x - mx)).toList(growable: false);
      final s = exps.fold<double>(0.0, (a, b) => a + b);
      probs = exps.map((e) => e / (s == 0 ? 1.0 : s)).toList(growable: false);
    }
    // ignore: avoid_print
    print('[Vision-Debug] Inference time: ${dtMs}ms');
    // ignore: avoid_print
    print('[Vision-Debug] Raw outputs: $raw');
    // Diversity diagnostics
    final maxProb = probs.reduce((a, b) => a > b ? a : b);
    final minProb = probs.reduce((a, b) => a < b ? a : b);
    final meanProb = probs.fold(0.0, (p, c) => p + c) / probs.length;
    double variance = 0.0;
    for (final p in probs) {
      variance += (p - meanProb) * (p - meanProb);
    }
    variance /= probs.length;
    if (variance < 0.01) {
      // ignore: avoid_print
      print('[Vision-Warning] Low output variance: ${variance.toStringAsFixed(4)} (min=${minProb.toStringAsFixed(3)}, max=${maxProb.toStringAsFixed(3)})');
    }
    // ignore: avoid_print
    print('[V-OUT] probs: ${probs.map((e) => e.toStringAsFixed(3)).toList()}');
    return probs;
  }
}


