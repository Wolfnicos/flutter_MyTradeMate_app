import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// MyTradeMate on-device models loader (direction / return / volatility).
class MtmModels {
  static MtmModels? _i;
  static Future<MtmModels> instance() async {
    _i ??= MtmModels();
    await _i!._ensureLoaded();
    return _i!;
  }
  late final tfl.Interpreter _dir;
  late final tfl.Interpreter _ret;
  late final tfl.Interpreter _vol;
  late final List<String> featCols;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Healthcheck: attempts to load interpreters; throws if it fails
  Future<void> selfTest() async {
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      debugPrint('[MtmModels] FP16 ok, fallback F32 if FP16 fails');
      await load(fp16: true);
    } catch (_) {
      debugPrint('[MtmModels] FP16 failed → loading F32');
      await load(fp16: false);
    }
  }

  Future<void> load({bool fp16 = false}) async {
    featCols = List<String>.from(
      json.decode(await rootBundle.loadString('assets/models/feat_cols.json')),
    );

    Future<tfl.Interpreter> _load(String base) async {
      final path = fp16
          ? 'assets/models/${base}_fp16_builtin.tflite'
          : 'assets/models/${base}_f32_builtin.tflite';
      return tfl.Interpreter.fromAsset(path);
    }

    _dir = await _load('direction');
    _ret = await _load('return');
    _vol = await _load('volatility');

    _loaded = true;
  }

  /// Rulează modelul `direction` cu input [1, 64, nfeat] sau [1, nfeat].
  /// Acceptă orice structură compatibilă ca [Object].
  double predictDirection(Object input) {
    final out = List.filled(1, List.filled(1, 0.0));
    _dir.run(input, out);
    return (out[0][0] as num).toDouble();
  }

  /// Returnă next return (regression, linear).
  double predictReturn(Object input) {
    final out = List.filled(1, List.filled(1, 0.0));
    _ret.run(input, out);
    return (out[0][0] as num).toDouble();
  }

  /// Returnă volatilitatea (regression).
  double predictVolatility(Object input) {
    final out = List.filled(1, List.filled(1, 0.0));
    _vol.run(input, out);
    return (out[0][0] as num).toDouble();
  }

  void dispose() {
    if (!_loaded) return;
    _dir.close();
    _ret.close();
    _vol.close();
    _loaded = false;
  }

  // Test support: allow bypassing asset loading and mark model as loaded with
  // a provided feature column list. This avoids IO in unit tests.
  @visibleForTesting
  void markLoadedForTest(List<String> cols) {
    featCols = cols;
    _loaded = true;
  }
}


class MtmOutput {
  final double probUp, nextReturn, volatility;
  const MtmOutput(this.probUp, this.nextReturn, this.volatility);
}

extension MtmRun on MtmModels {
  Future<MtmOutput> runFor(List<double> feat) async {
    final p = predictDirection([feat]);
    final r = predictReturn([feat]);
    final v = predictVolatility([feat]);
    return MtmOutput(p, r, v);
  }

  /// Run on a full time sequence shaped [64, nfeat].
  Future<MtmOutput> runSequence(List<List<double>> seq) async {
    // Model expects [1, 64, nfeat]
    final input = [seq];
    final p = predictDirection(input);
    final r = predictReturn(input);
    final v = predictVolatility(input);
    return MtmOutput(p, r, v);
  }

  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
      Map<String, double> features) async {
    await _ensureLoaded();
    final vector = featCols.map((k) => features[k] ?? 0.0).toList();
    try {
      final out = await runFor(vector);
      return (probUp: out.probUp, nextReturn: out.nextReturn, volatility: out.volatility);
    } catch (_) {
      return (probUp: null, nextReturn: null, volatility: null);
    }
  }

  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
      List<List<double>> seq) async {
    await _ensureLoaded();
    try {
      final out = await runSequence(seq);
      return (probUp: out.probUp, nextReturn: out.nextReturn, volatility: out.volatility);
    } catch (_) {
      return (probUp: null, nextReturn: null, volatility: null);
    }
  }
}


