import 'dart:convert';
import 'package:crypto/crypto.dart' show sha1;
import 'log_sink.dart';
import 'package:mytrademate/ai/ai_config.dart';
import 'package:mytrademate/ai/entities.dart' as ai;

class PredictionTrace {
  final String symbol;
  final DateTime asOf;
  final String modelRev;
  final double pBuy;
  final double expReturn;
  final double annVol;
  final int seed;
  final int window;
  final String timeframe;
  final Map<String, dynamic> meta; // e.g., {'fp16Fallbacks': {...}, 'featuresHash': '...'}
  PredictionTrace({
    required this.symbol,
    required this.asOf,
    required this.modelRev,
    required this.pBuy,
    required this.expReturn,
    required this.annVol,
    required this.seed,
    required this.window,
    required this.timeframe,
    required this.meta,
  });

  Map<String, dynamic> toJson() => {
    'ts': DateTime.now().toUtc().toIso8601String(),
    'asOf': asOf.toUtc().toIso8601String(),
    'symbol': symbol,
    'modelRev': modelRev,
    'pBuy': pBuy,
    'expReturn': expReturn,
    'annVol': annVol,
    'seed': seed,
    'window': window,
    'timeframe': timeframe,
    'meta': meta,
  };

  static String featuresHash(List<double> features) {
    final bytes = utf8.encode(features.map((e) => e.toStringAsFixed(8)).join(','));
    return sha1.convert(bytes).toString();
  }
}

class PredictionTracer {
  final LogSink sink;
  PredictionTracer(this.sink);

  Future<void> log({
    required ai.Prediction pred,
    required String modelRev,
    required List<double>? features, // dacă ai features; altfel treci null
    Map<String, dynamic>? fp16Flags, // {'dir': bool, 'ret': bool, 'vol': bool}
  }) async {
    final trace = PredictionTrace(
      symbol: pred.symbol,
      asOf: pred.asOf,
      modelRev: modelRev,
      pBuy: pred.pBuy,
      expReturn: pred.expReturn,
      annVol: pred.annVol,
      seed: AiConfig.seed,
      window: AiConfig.window,
      timeframe: AiConfig.timeframe,
      meta: {
        if (features != null) 'featuresHash': PredictionTrace.featuresHash(features),
        if (fp16Flags != null) 'fp16Fallbacks': fp16Flags,
      },
    );
    await sink.write(trace.toJson());
  }
}


