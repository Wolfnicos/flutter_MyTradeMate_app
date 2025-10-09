import 'package:flutter/foundation.dart';
import 'signal_engine.dart';
import 'engine_interface.dart';
import 'models/direction_model.dart';
import 'models/return_model.dart';
import 'models/volatility_model.dart';
import 'entities.dart';
import 'prediction_repo.dart';
import 'prediction_cache.dart';
import 'ai_config.dart';
import '../services/ohlcv_service.dart';
import 'package:mytrademate/obs/prediction_trace.dart';
import 'package:mytrademate/obs/log_sink.dart';
import 'dart:io' show File; // for FileJsonlSink path
import 'package:path_provider/path_provider.dart' as pp;

/// AILocator - Singleton global pentru acces la SignalEngine
/// Inițializează toate modelele ML și le face disponibile în toată aplicația
class AILocator {
  static final AILocator _instance = AILocator._internal();
  static AILocator get I => _instance;

  AILocator._internal() {
    // Initialize cache cu TTL from config
    cache = PredictionCache();
  }

  ISignalEngine? _engine;
  PredictionRepo? _repo;
  bool _initialized = false;
  bool _initInProgress = false;
  LogSink? _sink; // initialized lazily
  
  /// Cache pentru predicții (evită apeluri duplicate)
  late final PredictionCache cache;

  /// Get engine (throws dacă nu e inițializat)
  ISignalEngine get engine {
    if (_engine == null) {
      throw StateError(
        'AILocator not initialized! Call await AILocator.I.init() in main()',
      );
    }
    return _engine!;
  }

  /// Get prediction repository (RECOMMENDED for all UI!)
  PredictionRepo get repo {
    if (_repo == null) {
      throw StateError('AILocator not initialized!');
    }
    return _repo!;
  }

  /// Check dacă e inițializat
  bool get isInitialized => _initialized;

  /// Initialize ML pipeline (call în main() DUPĂ WidgetsFlutterBinding.ensureInitialized())
  Future<void> init({StrategySettings? settings}) async {
    if (_initialized) {
      debugPrint('✅ AILocator already initialized');
      return;
    }

    if (_initInProgress) {
      debugPrint('⏳ AILocator init in progress...');
      return;
    }

    _initInProgress = true;
    debugPrint('🚀 AILocator initializing...');

    try {
      // Create all 3 models
      final dirModel = DirectionModel();
      final retModel = ReturnModel();
      final volModel = VolatilityModel();

      // Models will lazy-load on first predict() call
      debugPrint('✅ AI Models created (lazy loading)');
      debugPrint('   - DirectionModel ready');
      debugPrint('   - ReturnModel ready');
      debugPrint('   - VolatilityModel ready');

      // Create SignalEngine with all models
      _engine = SignalEngine(
        dirModel: dirModel,
        returnModel: retModel,
        volatilityModel: volModel,
        settings: settings ?? const StrategySettings(
          upThresh: AiConfig.upThresh,
          downThresh: AiConfig.downThresh,
          confThresh: AiConfig.confThresh,
          timeframe: AiConfig.timeframe,
          window: AiConfig.window,
          history: AiConfig.history,
          seed: AiConfig.seed,
        ),
      );

      // Create PredictionRepo (centralized access point!)
      final ohlcvService = await OHLCVService.createFromPrefs();
      _repo = PredictionRepo(ohlcvService);

      _initialized = true;
      _initInProgress = false;

      debugPrint('✅ AILocator initialized successfully!');
      debugPrint('   - SignalEngine ready (Direction, Return, Volatility)');
      debugPrint('   - PredictionRepo ready (cache TTL: ${AiConfig.cacheTtl.inSeconds}s)');
      debugPrint('   - Window: ${AiConfig.kWindow}, Interval: ${AiConfig.kInterval}');
    } catch (e, stack) {
      _initInProgress = false;
      debugPrint('❌ AILocator init failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// Dispose (pentru cleanup la închiderea app)
  void dispose() {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
    debugPrint('🗑️ AILocator disposed');
  }

  // Testing hook: override engine for deterministic tests
  @visibleForTesting
  void overrideEngineForTests(ISignalEngine engine) {
    _engine?.dispose();
    _engine = engine;
    _initialized = true;
  }
}

/// Extension pentru access mai ușor
extension AILocatorExt on AILocator {
  /// Get prediction via repository (RECOMMENDED!)
  /// Uses cache + symbol mapping + OHLCV fetch
  Future<Prediction?> getPrediction(String uiSymbol) async {
    if (!isInitialized) {
      debugPrint('⚠️ AILocator not initialized!');
      return null;
    }
    final pred = await repo.getFor(uiSymbol);
    if (pred != null) {
      // Derive final action using current thresholds before tracing
      final finalAction = decide(pred);
      // init sink once
      _sink ??= kIsWeb
          ? InMemorySink()
          : FileJsonlSink(() async {
              final dir = await pp.getApplicationDocumentsDirectory();
              return File('${dir.path}/prediction_traces.jsonl');
            }());
      final tracer = PredictionTracer(_sink!);
      try {
        await tracer.log(
          pred: pred,
          modelRev: AiConfig.modelRev,
          features: null,
          fp16Flags: null,
        );
      } catch (_) {
        // best-effort logging only
      }
    }
    return pred;
  }

  /// Quick decide (null-safe)
  String decide(Prediction? prediction) {
    if (!isInitialized || prediction == null) {
      return 'HOLD'; // Safe default
    }
    return engine.decide(prediction);
  }
  
  /// Clear cache pentru un symbol
  void clearCacheFor(String symbol) {
    if (!isInitialized) return;
    repo.clearCache(symbol);
  }
  
  /// Clear tot cache-ul
  void clearAllCache() {
    if (!isInitialized) return;
    repo.clearAllCache();
  }
}

