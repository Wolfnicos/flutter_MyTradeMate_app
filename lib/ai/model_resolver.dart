import 'package:flutter/services.dart' show rootBundle;

class ModelResolver {
  /// Resolve per-symbol, per-timeframe PatchTST model asset path.
  /// Tries FP16 first, then F32. Returns null if none found and logs a skip message.
  static Future<String?> resolveTsModelPath(String symbol, String timeframe) async {
    final sym = symbol.toUpperCase();
    final tf = timeframe;
    final fp16 = 'assets/models/patchtst_${sym}_${tf}_fp16.tflite';
    final f32 = 'assets/models/patchtst_${sym}_${tf}_f32.tflite';
    try {
      await rootBundle.load(fp16);
      // ignore: avoid_print
      print('[TS-Model] resolve $sym/$tf -> $fp16');
      return fp16;
    } catch (_) {}
    try {
      await rootBundle.load(f32);
      // ignore: avoid_print
      print('[TS-Model] resolve $sym/$tf -> $f32');
      return f32;
    } catch (_) {}
    // ignore: avoid_print
    print('[Resolver] missing model for $sym/$tf → skip');
    return null;
  }
}


