import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OrderHistory add/list/clear', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = OrderHistoryRepository.instance;

    final o = Order(
      id: '1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 1000.0,
      executedQty: 0.01,
      status: 'FILLED',
      env: TradeEnv.testnet,
    );

    await repo.addOrder(o);
    var list = await repo.getOrders(TradeEnv.testnet);
    expect(list.length, 1);
    expect(list.first.side, 'BUY');

    await repo.clear(TradeEnv.testnet);
    list = await repo.getOrders(TradeEnv.testnet);
    expect(list, isEmpty);
  });
}



