// tool/run_backtest_simple.dart
// Versiune simplificată - PURE DART, fără Flutter framework

import 'dart:io';

void main(List<String> args) async {
  print('🚀 Simple Backtest Runner (Pure Dart)');
  print('=' * 80);
  
  final symbol = args.isNotEmpty ? args[0] : 'BTCUSDT';
  final days = args.length > 1 ? int.tryParse(args[1]) ?? 7 : 7;
  
  print('Symbol: $symbol');
  print('Period: $days days');
  print('=' * 80);
  
  print('\n⚠️  This script requires running within the Flutter app context.');
  print('The backtest system uses Flutter-dependent code (TFLite, AILocator, etc.)');
  print('\nTo run backtest, you have 2 options:\n');
  
  print('OPTION 1: Run in app');
  print('  1. Open the app: flutter run');
  print('  2. Navigate to Backtest screen');
  print('  3. Configure and run from UI\n');
  
  print('OPTION 2: Create integration test');
  print('  1. Create: integration_test/backtest_runner_test.dart');
  print('  2. Run: flutter test integration_test/backtest_runner_test.dart\n');
  
  print('Would you like me to create the integration test? (y/n)');
  final response = stdin.readLineSync();
  
  if (response?.toLowerCase() == 'y') {
    await _createIntegrationTest();
  }
}

Future<void> _createIntegrationTest() async {
  final testCode = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run backtest experiments', (WidgetTester tester) async {
    print('🚀 Initializing...');
    await AILocator.init();
    
    final ohlcv = await OHLCVService.createFromPrefs();
    final backtester = Backtester(
      engine: AILocator.I.engine,
      ohlcv: ohlcv,
    );
    
    print('📊 Loading candles...');
    final candles = await ohlcv.fetchCandles(
      symbol: 'BTCUSDT',
      interval: '5m',
      limit: 500,
    );
    
    print('✅ Loaded \${candles.length} candles');
    
    print('🧪 Running backtest...');
    final result = await backtester.run(
      symbol: 'BTCUSDT',
      interval: '5m',
      initialCapital: 10000,
      window: 64,
      horizon: 1,
      preloaded: candles,
      ensemble: AILocator.I.ensemble,
    );
    
    print('\\n' + '=' * 80);
    print('📈 RESULTS');
    print('=' * 80);
    print('Total Return: \${result.totalReturn.toStringAsFixed(2)}%');
    print('Sharpe Ratio: \${result.sharpeRatio.toStringAsFixed(2)}');
    print('Max Drawdown: \${result.maxDrawdown.toStringAsFixed(2)}%');
    print('Win Rate: \${result.winRate.toStringAsFixed(1)}%');
    print('Trades: \${result.trades.length}');
    print('=' * 80);
    
    expect(result.trades.isNotEmpty, true);
  });
}
''';

  final file = File('integration_test/backtest_runner_test.dart');
  await file.parent.create(recursive: true);
  await file.writeAsString(testCode);
  
  print('✅ Created: integration_test/backtest_runner_test.dart');
  print('\nRun with:');
  print('  flutter test integration_test/backtest_runner_test.dart');
}