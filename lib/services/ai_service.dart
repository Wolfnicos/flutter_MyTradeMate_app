import 'package:mytrademate/services/dio_binance_client.dart' as api;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mytrademate/services/mtm_models.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:mytrademate/services/calibration.dart';

class AIPrediction {
  final String action; // 'BUY', 'SELL', 'HOLD'
  final double confidence; // 0..100
  final double targetPrice;
  final String volatility; // label LOW/MEDIUM/HIGH
  final double probUp; // raw model probability
  final double nextReturn; // raw model next return
  final double volatilityValue; // raw model volatility

  const AIPrediction({
    required this.action,
    required this.confidence,
    required this.targetPrice,
    required this.volatility,
    required this.probUp,
    required this.nextReturn,
    required this.volatilityValue,
  });
}

/// Minimal client interface for testability
abstract class BinanceClientLike {
  Future<Map<String, dynamic>> ticker24h(String symbol);
  Future<double> tickerPrice(String symbol);
  Future<List<List<num>>> klines(String symbol, String interval, {int limit});
}

class _DioClientAdapter implements BinanceClientLike {
  final api.DioBinanceClient inner;
  _DioClientAdapter(this.inner);

  @override
  Future<List<List<num>>> klines(String symbol, String interval, {int limit = 200}) =>
      inner.klines(symbol, interval, limit: limit);

  @override
  Future<double> tickerPrice(String symbol) => inner.tickerPrice(symbol);

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) => inner.ticker24h(symbol);
}

/// Models adapter for testability
abstract class ModelsAdapter {
  List<String> get featCols;
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
      Map<String, double> features);
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
      List<List<double>> seq);
}

class _RealModelsAdapter implements ModelsAdapter {
  final MtmModels _m;
  _RealModelsAdapter(this._m);

  @override
  List<String> get featCols => _m.featCols;

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
    Map<String, double> features,
  ) => _m.predictAll(features);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
    List<List<double>> seq,
  ) => _m.predictAllFromSequence(seq);
}

class AIService {
  final bool enableFake;
  final BinanceClientLike? client;
  final ModelsAdapter? models;
  final FeatureBuilder? fb;
  static Calibrator? _cachedCalibrator; // cache to avoid I/O per inference
  static DateTime? _lastLoad;

  AIService({this.enableFake = false, this.client, this.models, this.fb});

  Future<AIPrediction> inferForSymbol(String symbol) => getPrediction(symbol);

  Future<AIPrediction> getPrediction(String symbol) async {
    // Enable fully deterministic, network-free mode in tests
    const bool aiFake = bool.fromEnvironment('AI_FAKE', defaultValue: false);
    if (aiFake || enableFake) {
      // Basic deterministic signal: BUY 60%, +2% target, Medium vol
      return const AIPrediction(
        action: 'BUY',
        confidence: 60.0,
        targetPrice: 102.0,
        volatility: 'Medium',
        probUp: 0.60,
        nextReturn: 0.02,
        volatilityValue: 0.05,
      );
    }
    final sym = _toBinanceSymbol(symbol);
    try {
      // 1) fetch live prices (use injected client if provided)
      final cli = client ?? _DioClientAdapter(await api.DioBinanceClient.createFromPrefs());
      Map<String, dynamic> t;
      try {
        t = await cli.ticker24h(sym);
      } catch (_) {
        final p = await cli.tickerPrice(sym);
        t = {'lastPrice': p, 'prevClosePrice': p};
      }
      final rawLast = t['lastPrice'];
      final double last = rawLast is num ? rawLast.toDouble() : double.parse(rawLast.toString());
      final rawPrev = t['prevClosePrice'];
      final double prev = rawPrev == null
          ? last
          : (rawPrev is num ? rawPrev.toDouble() : double.parse(rawPrev.toString()));

      // 2) Build features. Prefer full 64-step sequence from klines for the models.
      final ModelsAdapter adapter;
      if (models != null) {
        adapter = models!;
      } else {
        final m = await MtmModels.instance();
        adapter = _RealModelsAdapter(m);
      }
      final FeatureBuilder builder = fb ?? FeatureBuilder(adapter.featCols);
      ({double? probUp, double? nextReturn, double? volatility}) out;
      try {
        final kl = await cli.klines(sym, '5m', limit: 128);
        final closes = kl.map<double>((row) {
          final v = row[4];
          return (v as num).toDouble();
        }).toList();
        final seq = builder.sequenceFromCloses(closes, length: 64);
        out = await adapter.predictAllFromSequence(seq);
      } catch (_) {
        final feats = builder.fromTicker(last: last, prev: prev);
        out = await adapter.predictAll(feats);
      }
      double prob = (out.probUp ?? 0.5).toDouble();
      // Optional post-training calibration with cache + hot-reload in debug
      try {
        Calibrator? cal = _cachedCalibrator;
        final debugMode = () {
          var inDebug = false; assert(() { inDebug = true; return true; }()); return inDebug;
        }();
        final shouldReload = debugMode && (_lastLoad == null || DateTime.now().difference(_lastLoad!) > const Duration(seconds: 5));
        if (cal == null || shouldReload) {
          cal = await CalibrationStore.tryLoadFromAssets();
          _cachedCalibrator = cal; _lastLoad = DateTime.now();
        }
        if (cal != null) {
          final raw = prob;
          prob = cal.calibrate(prob).clamp(1e-9, 1 - 1e-9);
          assert(() {
            // log 1/200 calls in debug for drift checks
            if (DateTime.now().millisecond % 200 == 0) {
              // ignore: avoid_print
              print('[AI] prob_raw=${raw.toStringAsFixed(4)} → prob_cal=${prob.toStringAsFixed(4)}');
            }
            return true;
          }());
        }
      } catch (_) {}
      final double nextR = (out.nextReturn ?? 0.0).toDouble();
      final double vol = (out.volatility ?? 0.0).toDouble();
      final action = prob >= 0.55 ? 'BUY' : (prob <= 0.45 ? 'SELL' : 'HOLD');
      final double confidence = (prob * 100).clamp(0.0, 100.0).toDouble();
      // naive target: next 24h = last * (1 + nextR)
      final double targetPrice = last * (1 + nextR);
      final volatilityLabel = _volLabel(vol);
      return AIPrediction(
        action: action,
        confidence: confidence,
        targetPrice: targetPrice,
        volatility: volatilityLabel,
        probUp: prob,
        nextReturn: nextR,
        volatilityValue: vol,
      );
    } catch (e) {
      // surface a friendly message via thrown error
      throw Exception('AI unavailable: ${e.toString()}');
    }
  }
}

String _toBinanceSymbol(String s) {
  var up = s.toUpperCase().replaceAll('/', '').replaceAll(RegExp(r'\s+'), '');
  if (up.endsWith('USD')) {
    up = up.substring(0, up.length - 3) + 'USDT';
  }
  return up;
}

String _volLabel(double v) {
  final a = v.abs();
  if (a >= 0.10) return 'HIGH';
  if (a >= 0.03) return 'MEDIUM';
  return 'LOW';
}

@visibleForTesting
String volLabelForTest(double v) => _volLabel(v);

@visibleForTesting
String toBinanceSymbolForTest(String s) => _toBinanceSymbol(s);

@visibleForTesting
List<List<double>> featuresFromTickerForTest(double last) {
  // Build a minimal 64-step sequence from a single last price, mirroring
  // the internal fallback behavior used when klines are unavailable.
  final builder = FeatureBuilder();
  return builder.sequenceFromCloses([last], length: 64);
}

class ExplainData {
  final String symbol;
  final double probUp;
  final double nextReturn;
  final double volatility;
  final String volatilityLabel;
  final List<List<double>> features; // 64×N
  const ExplainData({
    required this.symbol,
    required this.probUp,
    required this.nextReturn,
    required this.volatility,
    required this.volatilityLabel,
    required this.features,
  });
}

@visibleForTesting
ExplainData mapToExplain(String symbol, List<List<double>> seq, AIPrediction r) {
  return ExplainData(
    symbol: symbol,
    probUp: r.probUp,
    nextReturn: r.nextReturn,
    volatility: r.volatilityValue,
    volatilityLabel: r.volatility,
    features: seq,
  );
}

class AiInference {
  final AIPrediction result;
  final ExplainData explain;
  AiInference(this.result, this.explain);
}

/// Deterministic offline inference for tests: skip network, use provided
/// sequence and last price. Returns both prediction and explain mapping.
@visibleForTesting
Future<AiInference> inferAndExplainForTest({
  required String symbol,
  required List<List<double>> seq,
  required double last,
  required MtmModels models,
}) async {
  final out = await models.runSequence(seq);
  final double prob = out.probUp;
  final double nextR = out.nextReturn;
  final double vol = out.volatility;
  final action = prob >= 0.55 ? 'BUY' : (prob <= 0.45 ? 'SELL' : 'HOLD');
  final double confidence = (prob * 100).clamp(0.0, 100.0).toDouble();
  final double targetPrice = last * (1 + nextR);
  final volatilityLabel = _volLabel(vol);
  final res = AIPrediction(
    action: action,
    confidence: confidence,
    targetPrice: targetPrice,
    volatility: volatilityLabel,
    probUp: prob,
    nextReturn: nextR,
    volatilityValue: vol,
  );
  final exp = mapToExplain(symbol, seq, res);
  return AiInference(res, exp);
}


