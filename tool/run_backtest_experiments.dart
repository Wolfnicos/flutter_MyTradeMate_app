import 'dart:io';

import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/ensemble/ensemble_predictor.dart';
import 'package:mytrademate/ai/ensemble/model_weights.dart';
import 'package:mytrademate/ai/ensemble/performance_tracker.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/models/return_model.dart';
import 'package:mytrademate/ai/models/volatility_model.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/backtesting/backtest_repository.dart';
import 'package:mytrademate/backtesting/historical_data_loader.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

class ExperimentConfig {
  final String name;
  final bool useEnsemble;
  final String? modelName; // 'direction'|'return'|'volatility' for baseline
  final double boost;
  final double penalty;
  const ExperimentConfig({
    required this.name,
    required this.useEnsemble,
    this.modelName,
    this.boost = EnsemblePredictor.CONSENSUS_BOOST,
    this.penalty = EnsemblePredictor.CONSENSUS_PENALTY,
  });
}

Future<void> main(List<String> args) async {
  print('🚀 Backtest Experiments Runner');
  print('=' * 60);

  final symbol = args.isNotEmpty ? args[0] : 'BTCUSDT';
  final days = args.length > 1 ? int.tryParse(args[1]) ?? 7 : 7;
  final outputDir = args.length > 2 ? args[2] : 'backtest_results';
  Directory(outputDir).createSync(recursive: true);

  print('Symbol: $symbol');
  print('Period: $days days');
  print('Output: $outputDir/');
  print('=' * 60);

  // Init AI
  await AILocator.I.init();
  final ohlcv = await OHLCVService.createFromPrefs();
  final loader = HistoricalDataLoader(ohlcv);

  // Load data (5m)
  print('\n📊 Loading historical data...');
  final limit = (days * 24 * 60 / 5).toInt();
  final candles = await loader.fromExchange(symbol, interval: '5m', limit: limit);
  print('✅ Loaded ${candles.length} candles');

  // Prepare base models
  final dir = DirectionModel();
  final ret = ReturnModel();
  final vol = VolatilityModel();

  final experiments = <ExperimentConfig>[
    const ExperimentConfig(name: 'Direction Model Only', useEnsemble: false, modelName: 'direction'),
    const ExperimentConfig(name: 'Return Model Only', useEnsemble: false, modelName: 'return'),
    const ExperimentConfig(name: 'Volatility Model Only', useEnsemble: false, modelName: 'volatility'),
    const ExperimentConfig(name: 'Ensemble (default boost=0.15, penalty=0.10)', useEnsemble: true),
    const ExperimentConfig(name: 'Ensemble (boost=0.10)', useEnsemble: true, boost: 0.10, penalty: 0.10),
    const ExperimentConfig(name: 'Ensemble (boost=0.20)', useEnsemble: true, boost: 0.20, penalty: 0.10),
    const ExperimentConfig(name: 'Ensemble (boost=0.25)', useEnsemble: true, boost: 0.25, penalty: 0.10),
    const ExperimentConfig(name: 'Ensemble (penalty=0.05)', useEnsemble: true, boost: 0.15, penalty: 0.05),
    const ExperimentConfig(name: 'Ensemble (penalty=0.15)', useEnsemble: true, boost: 0.15, penalty: 0.15),
  ];

  final repo = await BacktestRepository.create();
  final summaryPath = '$outputDir/summary_${symbol}_${DateTime.now().toIso8601String().split('T').first}.csv';
  final summary = StringBuffer('name,finalCapital,totalReturn,maxDrawdown,sharpe,numTrades,winRate,feesPaid\n');

  for (final exp in experiments) {
    print('\n▶️  Running: ${exp.name}');
    final bt = Backtester(engine: AILocator.I.engine, ohlcv: ohlcv);
    EnsemblePredictor? ens;
    if (exp.useEnsemble) {
      ens = EnsemblePredictor(
        dirModel: dir,
        retModel: ret,
        volModel: vol,
        weights: ModelWeights(),
        tracker: PerformanceTracker(),
        boost: exp.boost,
        penalty: exp.penalty,
      );
    }

    final res = await bt.run(
      symbol: symbol,
      interval: '5m',
      initialCapital: 10000,
      preloaded: candles,
      ensemble: ens,
      window: 64,
      horizon: 1,
    );

    // Save equity JSON/CSV and trades CSV
    final json = await repo.saveJson(res);
    final csv = await repo.saveCsv(res);
    final tradesCsv = File('$outputDir/trades_${exp.name.replaceAll(' ', '_')}_${DateTime.now().toIso8601String().split('T').first}.csv');
    final tbuf = StringBuffer('time,action,price,qty,fee,pnl\n');
    for (final t in res.trades) {
      tbuf.writeln('${t.time.toIso8601String()},${t.action},${t.price},${t.qty},${t.fee},${t.pnl}');
    }
    await tradesCsv.writeAsString(tbuf.toString());

    final winRate = res.numTrades == 0 ? 0.0 : (res.winningTrades / res.numTrades);
    summary.writeln('${exp.name},${res.finalCapital.toStringAsFixed(2)},${(res.totalReturn * 100).toStringAsFixed(2)}%,${(res.maxDrawdown * 100).toStringAsFixed(2)}%,${res.sharpe.toStringAsFixed(2)},${res.numTrades},${(winRate * 100).toStringAsFixed(1)}%,${res.feesPaid.toStringAsFixed(2)}');
    print('✅ ${exp.name}: final=${res.finalCapital.toStringAsFixed(2)} PnL=${(res.totalReturn * 100).toStringAsFixed(2)}%');
  }

  final summaryFile = File(summaryPath);
  await summaryFile.writeAsString(summary.toString());
  print('\n📄 Summary: ${summaryFile.path}');
}


