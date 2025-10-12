import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/backtesting/backtester.dart';
import 'package:mytrademate/services/ohlcv_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run backtest experiments', (WidgetTester tester) async {
    print('🚀 Initializing...');
    await AILocator.I.init();
    
    final ohlcv = await OHLCVService.createFromPrefs();
    final backtester = Backtester(
      engine: AILocator.I.engine,
      ohlcv: ohlcv,
    );
    
    print('📊 Loading candles...');
    final candles = await ohlcv.fetchCandles('BTCUSDT', interval: '5m', limit: 500);
    
    print('✅ Loaded ${candles.length} candles');
    
    print('🧪 Running backtest...');
    final result = await backtester.run(
      symbol: 'BTCUSDT',
      interval: '5m',
      initialCapital: 10000,
      window: 64,
      horizon: 1,
      preloaded: candles,
      ensemble: null,
    );
    
    print('\n${'=' * 80}');
    print('📈 RESULTS');
    print('=' * 80);
    print('Total Return: ${(result.totalReturn * 100).toStringAsFixed(2)}%');
    print('Sharpe Ratio: ${result.sharpe.toStringAsFixed(2)}');
    print('Max Drawdown: ${(result.maxDrawdown * 100).toStringAsFixed(2)}%');
    final winRate = result.numTrades > 0 ? (result.winningTrades / result.numTrades) * 100.0 : 0.0;
    print('Win Rate: ${winRate.toStringAsFixed(1)}%');
    print('Trades: ${result.trades.length}');
    print('=' * 80);
    
    expect(result.trades.isNotEmpty, true);
  });
}
