import 'dart:collection';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import '../ai_predictor.dart';
import '../entities.dart';
import '../norm_loader.dart';
import '../ai_config.dart';

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
        if (shape.isNotEmpty) nOut = shape.last;
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

    final o = outputs[0] as List;
    try {
      // ignore: avoid_print
      print('[TS-OUT] head0 first6: ${o.take(6).toList()}');
    } catch (_) {}

    // Strict mapping assume canonical [buy,hold,sell] heads; else softmax and map
    double pBuy = _numToDouble(o, 0);
    double pHold = _numToDouble(o, 1);
    double pSell = _numToDouble(o, 2);

    // Softmax if not normalized
    final sum0 = pBuy + pHold + pSell;
    if (sum0 <= 0.0 || (sum0 - 1.0).abs() > 1e-3) {
      final mx = [pBuy, pHold, pSell].reduce((a, b) => a > b ? a : b);
      final exps = [math.exp(pBuy - mx), math.exp(pHold - mx), math.exp(pSell - mx)];
      final s = exps[0] + exps[1] + exps[2];
      pBuy = exps[0] / (s == 0 ? 1.0 : s);
      pHold = exps[1] / (s == 0 ? 1.0 : s);
      pSell = exps[2] / (s == 0 ? 1.0 : s);
    }
    // Ensure HOLD not zero if missing
    if (pHold == 0.0) {
      final rem = 1.0 - (pBuy + pSell);
      pHold = rem.clamp(0.0, 1.0);
    }

    // Compute realistic expReturn and annVol from recent window
    final returns = <double>[];
    final closeIdx = featureOrder.indexOf('close');
    for (int t = 1; t < aligned.length; t++) {
      final prev = aligned[t - 1][closeIdx];
      final curr = aligned[t][closeIdx];
      final r = prev == 0 ? 0.0 : (curr / prev - 1.0);
      returns.add(r);
    }
    double mean = 0.0;
    for (final r in returns) { mean += r; }
    mean = returns.isEmpty ? 0.0 : mean / returns.length;
    double variance = 0.0;
    for (final r in returns) { variance += (r - mean) * (r - mean); }
    variance = returns.isEmpty ? 0.0 : variance / returns.length;
    final std = math.sqrt(variance);
    final k = std * 0.75;
    final expRet = (pBuy - pSell) * k; // buy minus sell

    int minutesForTf(String tf) {
      switch (tf) {
        case '5m': return 5;
        case '15m': return 15;
        case '1h': return 60;
        case '4h': return 240;
        case '1d': return 1440;
        default: return 5;
      }
    }
    final annScale = math.sqrt((365*24*60) / minutesForTf(timeframe));
    final annVol = std * annScale;
    // ignore: avoid_print
    print('[TS-Metrics][$symbol@$timeframe] mean=${mean.toStringAsFixed(4)} std=${std.toStringAsFixed(4)} expRet=${(expRet*100).toStringAsFixed(2)}% annVol=${(annVol*100).toStringAsFixed(2)}%');

    return Prediction(
      symbol: symbol,
      asOf: window.last.time,
      pBuy: pBuy,
      pHold: pHold,
      pSell: pSell,
      expReturn: expRet,
      annVol: annVol,
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

  double _numToDouble(List o, int idx) {
    final v = (o.length > idx ? (o[idx] as num?)?.toDouble() : 0.0) ?? 0.0;
    return _clamp01(v);
  }

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
