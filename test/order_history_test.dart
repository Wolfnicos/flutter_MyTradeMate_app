import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart' as oh;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OrderHistoryRepository add/get/clear roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = oh.OrderHistoryRepository.instance;
    final o = oh.Order(
      id: '1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 50.0,
      executedQty: 0.001,
      status: 'FILLED',
      env: oh.TradeEnv.testnet,
    );

    await repo.addOrder(o);
    final list = await repo.getOrders(oh.TradeEnv.testnet);
    expect(list.isNotEmpty, true);
    expect(list.first.id, '1');

    await repo.clear(oh.TradeEnv.testnet);
    final after = await repo.getOrders(oh.TradeEnv.testnet);
    expect(after, isEmpty);
  });
}

