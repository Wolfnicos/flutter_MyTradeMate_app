import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/signal_engine.dart';
import 'package:mytrademate/backtesting/backtester.dart' as bt;
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/prediction_repo.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

/// Standalone script pentru a rula backtest și a genera raport
void main(List<String> args) async {
  print('🚀 MyTradeMate Backtester');
  print('═' * 50);

  final symbol = args.isNotEmpty ? args[0] : 'BTCUSDT';
  final days = args.length > 1 ? int.tryParse(args[1]) ?? 30 : 30;
  final capital = args.length > 2 ? double.tryParse(args[2]) ?? 10000 : 10000.0;
  final useNewTs = args.contains('--new-ts');

  print('Symbol: $symbol');
  print('Period: $days days');
  print('Initial Capital: \$${capital.toStringAsFixed(2)}');
  print('');

  if (useNewTs) {
    // New TS+Vision ensemble quick run (snapshot style)
    WidgetsFlutterBinding.ensureInitialized();
    await AILocator.I.init();
    final ohlcv = await OHLCVService.createFromPrefs();
    final repo = PredictionRepo(ohlcv);

    print('🔬 New TS+Vision (ensemble, multi-TF) snapshot...');
    final pred = await repo.getFor(symbol);
    if (pred == null) {
      print('❌ No prediction available');
      exit(1);
    }
    final action = AILocator.I.decide(pred);
    final conf = (pred.confidence() * 100).toStringAsFixed(1);
    final ret = (pred.expReturn * 100).toStringAsFixed(2);
    final vol = (pred.annVol * 100).toStringAsFixed(1);
    print('🤖 Ensemble ➜ $symbol: action=$action conf=$conf% ret=$ret% vol=$vol%');
    print('Done.');
    return;
  }

  // Legacy full-engine backtest
  final engine = SignalEngine.full(
    settings: const StrategySettings(
      upThresh: 0.003,
      downThresh: -0.003,
      confThresh: 0.6,
      volCap: 0.85,
      fee: 0.001,
      slippage: 0.0005,
    ),
  );

  final backtester = bt.Backtester(
    engine: engine,
    ohlcv: await OHLCVService.createFromPrefs(),
  );

  // Load or generate demo data
  print('📊 Loading historical data...');
  final data = await _loadData(symbol, days);
  
  if (data.isEmpty) {
    print('❌ No data available');
    return;
  }

  print('✅ Loaded ${data.length} candles');
  print('');

  // Run backtest
  print('🤖 Running backtest...');
  final result = await backtester.run(
    symbol: symbol,
    interval: '1h',
    initialCapital: capital,
    preloaded: data,
    positionSize: 0.1,
  );

  // Display results
  print('');
  print('📈 Results:');
  print('═' * 50);
  print('trades=${result.numTrades} wins=${result.winningTrades} losses=${result.losingTrades}');
  print('');
  print('Final Capital: \$${result.finalCapital.toStringAsFixed(2)}');
  print('P&L: \$${(result.finalCapital - capital).toStringAsFixed(2)}');
  print('');

  // Save results
  final reportDir = Directory('build/reports/backtests');
  await reportDir.create(recursive: true);
  
  final timestamp = DateTime.now().toIso8601String().split('T').first;
  final filename = '${symbol}_$timestamp.json';
  final file = File('${reportDir.path}/$filename');
  
  await file.writeAsString(jsonEncode(result.toJson()));
  
  print('💾 Report saved: ${file.path}');
  print('');
  print('✅ Backtest complete!');
}

/// Load mock data (în producție, ar veni de la Binance API)
Future<List<Candle>> _loadData(String symbol, int days) async {
  // Generate demo candles (trending up cu noise)
  final candles = <Candle>[];
  const basePrice = 100.0;
  
  for (int i = 0; i < days * 24; i++) { // 24 candles per day (hourly)
    final time = DateTime.now().subtract(Duration(hours: days * 24 - i));
    final trend = i * 0.1; // Slow uptrend
    final noise = (i % 10 - 5) * 0.5; // Noise
    
    final close = basePrice + trend + noise;
    final open = close - (i % 2 == 0 ? 0.2 : -0.2);
    final high = close + (noise.abs() + 0.5);
    final low = close - (noise.abs() + 0.5);
    final volume = 1000.0 + (i % 20) * 100;
    
    candles.add(Candle(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    ));
  }
  
  return candles;
}





