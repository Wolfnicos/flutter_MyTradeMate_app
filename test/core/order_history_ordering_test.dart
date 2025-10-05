import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('orders are persisted and ordering is stable (newest first)', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = OrderHistoryRepository.instance;

    await repo.clear(TradeEnv.testnet);

    final older = Order(
      id: '1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 1000.0,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(100),
    );
    final newer = Order(
      id: '2',
      symbol: 'BTCUSDT',
      side: 'SELL',
      quoteQty: 1100.0,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(200),
    );

    await repo.addOrder(older);
    await repo.addOrder(newer);

    final list = await repo.getOrders(TradeEnv.testnet);
    expect(list.length, 2);
    expect(list.first.ts.millisecondsSinceEpoch, 200);
    expect(list.last.ts.millisecondsSinceEpoch, 100);
  });
}


