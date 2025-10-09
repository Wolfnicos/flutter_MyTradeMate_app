import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OrderHistoryRepository saves and loads last orders', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = OrderHistoryRepository.instance;

    final order = Order(
      id: 't1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 1000.0,
      executedQty: 0.01,
      status: 'FILLED',
      env: TradeEnv.testnet,
    );

    await repo.addOrder(order);
    final all = await repo.getOrders(TradeEnv.testnet);
    expect(all, isNotEmpty);
    expect(all.first.symbol, 'BTCUSDT');
  });
}


