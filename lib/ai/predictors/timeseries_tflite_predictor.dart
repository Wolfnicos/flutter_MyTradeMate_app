import 'dart:collection';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import '../ai_predictor.dart';
import '../entities.dart';
import '../norm_loader.dart';

/// Time-series predictor backed by TFLite models per SYMBOL/TF.
/// Model path pattern: assets/models/patchtst_<SYMBOL>_<TF>_fp16.tflite
class TimeSeriesTflitePredictor implements AiPredictor {
  final Map<String, tfl.Interpreter> _cache =
      HashMap<String, tfl.Interpreter>();

  /// Resolve per-symbol, per-timeframe PatchTST model asset path.
  /// timeframe is one of: 5m, 15m, 1h, 4h, 1d
  String resolveTsModelPath(
      {required String symbol, required String timeframe}) {
    final tf = timeframe;
    final sym = symbol.toUpperCase();
    final path = 'assets/models/patchtst_${sym}_${tf}_fp16.tflite';
    // ignore: avoid_print
    print('[TS-Model] resolve ${symbol}/${timeframe} -> $path');
    return path;
  }

  @override
  Future<Prediction?> predict(
    String symbol,
    List<Candle> window, {
    required String timeframe,
  }) async {
    if (window.length < 64) {
      // Not enough data → safe HOLD
      return Prediction(
        symbol: symbol.toUpperCase(),
        asOf: window.isNotEmpty ? window.last.time : DateTime.now(),
        pBuy: 0.0,
        pHold: 1.0,
        pSell: 0.0,
        expReturn: 0.0,
        annVol: 0.0,
        relVolume: 1.0,
        reason: 'insufficient_data',
      );
    }

    // Load normalization spec (feature names + mean/std by name)
    final spec = await NormLoader.ensureLoaded();
    final featureOrder = spec
        .featureOrder; // e.g., [open,high,low,close,volume,ret_1,ema9,ema21,atr]

    // Build features as named columns, then map to featureOrder and normalize
    final normalized =
        _buildAndNormalize(window, featureOrder, spec.mean, spec.std);

    final key = _key(symbol, timeframe);
    final interp = await _getOrLoad(key, symbol, timeframe);
    if (interp == null) {
      // Return HOLD with explicit reason when model missing
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

    // Read input tensor shape and construct FEATURE-MAJOR [F,S] buffer
    List<int> shp = <int>[];
    try {
      shp = interp.getInputTensor(0).shape;
    } catch (_) {}
    final F = (shp.length >= 3) ? shp[1] : (spec.featureOrder.length);
    final S = (shp.length >= 3) ? shp[2] : (normalized.length);

    // Align normalized to target S (sequence length)
    List<List<double>> aligned;
    if (normalized.length == S) {
      aligned = normalized;
    } else if (normalized.length > S) {
      aligned = normalized.sublist(normalized.length - S);
    } else {
      // left-pad with first row
      final pad = List<List<double>>.filled(
          S - normalized.length,
          normalized.isNotEmpty
              ? normalized.first
              : List<double>.filled(F, 0.0));
      aligned = pad + normalized;
    }

    // FEATURE-MAJOR buffer [F,S]
    final int featCount = F;
    final int seqLen = S;
    final buf = List.generate(featCount * seqLen, (_) => 0.0);
    for (int t = 0; t < seqLen; t++) {
      for (int f = 0; f < featCount; f++) {
        final v = (f < aligned[t].length) ? aligned[t][f] : 0.0;
        buf[f * seqLen + t] = v;
      }
    }

    // Resize input if needed and allocate
    try {
      interp.resizeInputTensor(0, [1, featCount, seqLen]);
      interp.allocateTensors();
    } catch (_) {}

    // Build input [1, F, S]
    final input = [
      List.generate(
          featCount, (f) => List.generate(seqLen, (t) => buf[f * seqLen + t]))
    ];

    // Determine output length from tensor shape
    int nOut = 3;
    try {
      final outT = interp.getOutputTensors();
      if (outT.isNotEmpty) {
        final shape = outT.first.shape;
        if (shape.isNotEmpty) {
          nOut = shape.last;
        }
      }
    } catch (_) {}

    final outputs = [List.filled(nOut, 0.0)];
    try {
      interp.run(input, outputs);
      // ignore: avoid_print
      print('[TS-Model] ran with inputShape=[1,${featCount},${seqLen}]');
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
        reason: 'inference_error',
      );
    }

    final o = outputs[0];
    try {
      // ignore: avoid_print
      print('[TS-OUT] head0 first6: ${(o as List).take(6).toList()}');
    } catch (_) {}

    // Robust mapping of outputs (3 or 5 values)
    double pBuy, pHold, pSell, expRet = 0.0, annVol = 0.0;
    if (o.length >= 5) {
      pBuy = _clamp01((o[0] as num).toDouble());
      pHold = _clamp01((o[1] as num).toDouble());
      pSell = _clamp01((o[2] as num).toDouble());
      expRet = (o[3] as num).toDouble();
      annVol = (o[4] as num).toDouble().abs();
    } else if (o.length >= 3) {
      pBuy = _clamp01((o[0] as num).toDouble());
      pHold = _clamp01((o[1] as num).toDouble());
      pSell = _clamp01((o[2] as num).toDouble());
    } else {
      return Prediction(
        symbol: symbol.toUpperCase(),
        asOf: window.last.time,
        pBuy: 0.0,
        pHold: 1.0,
        pSell: 0.0,
        expReturn: 0.0,
        annVol: 0.0,
        relVolume: 1.0,
        reason: 'bad_output',
      );
    }

    // Optional softmax if not normalized
    final sum = pBuy + pHold + pSell;
    if (sum <= 0.0 || sum > 1.5) {
      final mx = [pBuy, pHold, pSell].reduce((a, b) => a > b ? a : b);
      final exps = [
        math.exp(pBuy - mx),
        math.exp(pHold - mx),
        math.exp(pSell - mx),
      ];
      final s = exps[0] + exps[1] + exps[2];
      pBuy = exps[0] / s;
      pHold = exps[1] / s;
      pSell = exps[2] / s;
    }

    // Placeholder proxies for UI metrics until heads are fully wired
    final pr = (pBuy - pSell).clamp(-1.0, 1.0);
    final expRetProxy = (pr * 0.35).clamp(-0.35, 0.35);
    final volProxy = annVol > 0 ? annVol : (0.15).clamp(0.0, 2.0);

    return Prediction(
      symbol: symbol,
      asOf: window.last.time,
      pBuy: pBuy,
      pHold: pHold,
      pSell: pSell,
      expReturn: expRetProxy,
      annVol: volProxy,
      relVolume: 1.0,
    );
  }

  Future<tfl.Interpreter?> _getOrLoad(
      String key, String symbol, String tf) async {
    final existing = _cache[key];
    if (existing != null) return existing;
    final path = resolveTsModelPath(symbol: symbol, timeframe: tf);
    try {
      final i = await tfl.Interpreter.fromAsset(path);
      _cache[key] = i;
      // ignore: avoid_print
      print('[TS-Model] loaded: $path');
      try {
        // ignore: avoid_print
        print('[TS-Model] inputShape: ${i.getInputTensor(0).shape}');
      } catch (_) {}
      try {
        // ignore: avoid_print
        print('[TS-Model] outputCount: ${i.getOutputTensors().length}');
      } catch (_) {}
      return i;
    } catch (_) {
      return null;
    }
  }

  String _key(String symbol, String tf) => '${symbol.toUpperCase()}@$tf';

  double _clamp01(double v) => v.isNaN || !v.isFinite ? 0.0 : v.clamp(0.0, 1.0);

  List<List<double>> _buildAndNormalize(
    List<Candle> window,
    List<String> featureOrder,
    Map<String, double> mean,
    Map<String, double> std,
  ) {
    // Use last 64 candles in chronological order
    final seq = window.sublist(window.length - 64);

    // Precompute helpers
    final closes = seq.map((c) => c.close).toList();
    final highs = seq.map((c) => c.high).toList();
    final lows = seq.map((c) => c.low).toList();
    // final vols = seq.map((c) => c.volume).toList();

    // EMA helper
    double emaAt(List<double> x, int idx, int p) {
      final start = 0;
      final alpha = 2.0 / (p + 1);
      double e = x[start];
      for (int i = start + 1; i <= idx; i++) {
        e = x[i] * alpha + e * (1 - alpha);
      }
      return e;
    }

    // ATR helper over rolling true range average (period 14)
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

    // Build normalized rows
    final out = <List<double>>[];
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
        final mu = mean[name] ?? 0.0;
        final sd = (std[name] ?? 1.0);
        final z = sd == 0 ? 0.0 : ((v - mu) / sd).clamp(-5.0, 5.0);
        row.add(z);
      }
      out.add(row);
    }
    return out;
  }
}
