// dart run tool/run_hybrid_strategies_offline.dart BTCUSDT
import 'dart:io';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/strategies/hybrid_strategies.dart' as hs;
import 'package:mytrademate/lib/backtesting/csv_loader.dart' as local_loader;

List<Candle> _synth(String tf, {int n = 1000}) {
  final now = DateTime.now();
  final candles = <Candle>[];
  Duration step;
  switch (tf) {
    case '5m': step = const Duration(minutes: 5); break;
    case '15m': step = const Duration(minutes: 15); break;
    case '1h': step = const Duration(hours: 1); break;
    case '4h': step = const Duration(hours: 4); break;
    case '1d': step = const Duration(days: 1); break;
    default: step = const Duration(minutes: 5);
  }
  double price = 100.0;
  for (int i = n - 1; i >= 0; i--) {
    final t = now.subtract(step * i);
    final drift = (0.0002 - 0.0001) * (i % 10 == 0 ? 2 : 1);
    final noise = (i % 7 - 3) * 0.01;
    price = price * (1.0 + drift + noise / 100.0);
    final open = price * (1 + (noise - 0.02) / 100.0);
    final close = price;
    final high = [open, close].reduce((a, b) => a > b ? a : b) * 1.005;
    final low = [open, close].reduce((a, b) => a < b ? a : b) * 0.995;
    candles.add(Candle(time: t, open: open, high: high, low: low, close: close, volume: 1000 + (i % 50) * 10));
  }
  return candles;
}

List<Candle> _loadOrSynth(String pathHint, String tf) {
  final file = File(pathHint);
  if (file.existsSync()) {
    return local_loader.CsvLoader.load(pathHint, limit: 3000);
  }
  return _synth(tf, n: 1500);
}

void main(List<String> args) {
  final symbol = args.isNotEmpty ? args[0] : 'BTCUSDT';
  print('🚀 Offline Hybrid Strategies Runner for $symbol');

  // Paths (optional); if not found, generate synthetic
  final p5m = 'test/fixtures/${symbol}_5m.csv';
  final p1h = 'test/fixtures/${symbol}_1h.csv';
  final p4h = 'test/fixtures/${symbol}_4h.csv';
  final p1d = 'test/fixtures/${symbol}_1d.csv';

  final tf5m = _loadOrSynth(p5m, '5m');
  final tf1h = _loadOrSynth(p1h, '1h');
  final tf4h = _loadOrSynth(p4h, '4h');
  final tf1d = _loadOrSynth(p1d, '1d');

  final Map<String, dynamic> s1 = hs.hybridStrategy1(tf5m: tf5m, tf4h: tf4h, tf1d: tf1d);
  final Map<String, dynamic> s2 = hs.hybridStrategy2(tf5m: tf5m, tf1h: tf1h, tf1d: tf1d);
  final Map<String, dynamic> s3 = hs.hybridStrategy3(tf15m: tf5m, tf4h: tf4h, tf1d: tf1d); // reuse 5m as 15m if missing
  final Map<String, dynamic> s4 = hs.hybridStrategy4(tf5m: tf5m, tf1h: tf1h, tf1d: tf1d);
  final Map<String, dynamic> s5 = hs.hybridStrategy5(tf5m: tf5m, tf4h: tf4h, tf1d: tf1d);

  void printRes(String name, Map<String, dynamic> r) {
    final act = r['action'];
    final conf = ((r['confidence'] ?? 0.0) as double) * 100.0;
    final sz = ((r['position_size'] ?? 0.0) as double) * 100.0;
    print('• $name -> action=$act, conf=${conf.toStringAsFixed(1)}%, size=${sz.toStringAsFixed(1)}%');
    if (r.containsKey('debug')) print('  debug: ${r['debug']}');
  }

  printRes('Strategy1 (EMA+RSI+Cloud)', s1);
  printRes('Strategy2 (BB+ADX+Cloud)', s2);
  printRes('Strategy3 (Trend+RSI)', s3);
  printRes('Strategy4 (Breakout+DailyTrend)', s4);
  printRes('Strategy5 (Vol-adaptive+Cloud)', s5);

  print('\n✅ Done. You can provide CSVs in test/fixtures to replace synthetic data.');
}


