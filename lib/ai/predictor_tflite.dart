import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'norm_loader.dart';
import 'ai_predictor.dart';
import 'entities.dart';

/// Resolve per-symbol, per-timeframe PatchTST TFLite model path.
/// timeframe is one of: 5m, 15m, 1h, 4h, 1d
String resolveTsModelPath({required String symbol, required String timeframe}) {
  final tf = timeframe;
  final sym = symbol.toUpperCase();
  return 'assets/models/patchtst_${sym}_${tf}_fp16.tflite';
}

class TflitePatchTstPredictor implements AiPredictor {
  final Map<String, tfl.Interpreter> _cache = {};
  Future<tfl.Interpreter> _get(String symbol, String tf) async {
    final key = '$symbol|$tf';
    if (_cache[key] != null) return _cache[key]!;
    final name = resolveTsModelPath(symbol: symbol, timeframe: tf);
    try {
      final i = await tfl.Interpreter.fromAsset(name);
      _cache[key] = i;
      return i;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Prediction?> predict(
    String symbol,
    List<Candle> window, {
    required String timeframe,
  }) async {
    if (window.length < 64) return null;

    final spec = await NormLoader.ensureLoaded();
    final featureOrder = spec.featureOrder;

    // Use last 64 candles
    final seq = window.sublist(window.length - 64);
    final closes = seq.map((c) => c.close).toList();
    final highs = seq.map((c) => c.high).toList();
    final lows = seq.map((c) => c.low).toList();
    final outSeq = <List<double>>[];

    double emaAt(List<double> x, int idx, int p) {
      final alpha = 2.0 / (p + 1);
      double e = x[0];
      for (int i = 1; i <= idx; i++) {
        e = x[i] * alpha + e * (1 - alpha);
      }
      return e;
    }

    double atrAt(int idx, {int period = 14}) {
      int start = idx - period + 1;
      if (start < 1) start = 1;
      double sum = 0.0;
      int n = 0;
      for (int i = start; i <= idx; i++) {
        final high = highs[i];
        final low = lows[i];
        final prevClose = closes[i - 1];
        final tr = [
          high - low,
          (high - prevClose).abs(),
          (low - prevClose).abs()
        ].reduce((a, b) => a > b ? a : b);
        sum += tr;
        n += 1;
      }
      return n == 0 ? 0.0 : sum / n;
    }

    for (int i = 0; i < seq.length; i++) {
      final c = seq[i];
      final prevClose = i == 0 ? c.close : closes[i - 1];
      final featsByName = <String, double>{
        'open': c.open,
        'high': c.high,
        'low': c.low,
        'close': c.close,
        'volume': c.volume,
        'ret_1': prevClose == 0 ? 0.0 : (c.close / prevClose - 1.0),
        'ema9': emaAt(closes, i, 9),
        'ema21': emaAt(closes, i, 21),
        'atr': i == 0 ? 0.0 : atrAt(i, period: 14),
      };
      final row = <double>[];
      for (final name in featureOrder) {
        final v = featsByName[name] ?? 0.0;
        final mu = spec.mean[name] ?? 0.0;
        final sd = (spec.std[name] ?? 1.0);
        final z = sd == 0 ? 0.0 : ((v - mu) / sd).clamp(-5.0, 5.0);
        row.add(z);
      }
      outSeq.add(row);
    }

    final input = [outSeq];
    tfl.Interpreter? interpreter;
    try {
      interpreter = await _get(symbol, timeframe);
    } catch (_) {
      return Prediction(
        symbol: symbol.toUpperCase(),
        asOf: window.last.time,
        pBuy: 0.0,
        pHold: 1.0,
        pSell: 0.0,
        expReturn: 0.0,
        annVol: 0.0,
        relVolume: 1.0,
        reason: 'model_missing',
      );
    }

    // Assume 3-class output [pBuy,pHold,pSell]
    final out = [List.filled(3, 0.0)];
    try {
      interpreter.run(input, out);
    } catch (_) {
      return null;
    }
    final o = out[0];
    final pBuy = (o[0] as num).toDouble();
    final pHold = (o[1] as num).toDouble();
    final pSell = (o[2] as num).toDouble();

    return Prediction(
      symbol: symbol.toUpperCase(),
      asOf: window.last.time,
      pBuy: pBuy,
      pHold: pHold,
      pSell: pSell,
      expReturn: 0.0,
      annVol: 0.0,
      relVolume: 1.0,
    );
  }
}
