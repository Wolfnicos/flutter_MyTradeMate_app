import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add/list/clear persists roundtrip', () async {
    final repo = OrderHistoryRepository.instance;
    await repo.clear(TradeEnv.testnet);
    expect((await repo.getOrders(TradeEnv.testnet)).isEmpty, isTrue);

    final o1 = Order(
      id: 'o1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 10000,
      executedQty: 0.1,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(1),
    );
    final o2 = Order(
      id: 'o2',
      symbol: 'ETHUSDT',
      side: 'SELL',
      quoteQty: 2000,
      executedQty: 1.2,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(2),
    );

    await repo.addOrder(o1);
    await repo.addOrder(o2);

    final list1 = await repo.getOrders(TradeEnv.testnet);
    expect(list1.length, 2);
    expect(list1.first.id, 'o2'); // newest first

    // Re-fetch simulates reopen (prefs-backed)
    final list2 = await repo.getOrders(TradeEnv.testnet);
    expect(list2.map((e) => e.id).toList(), ['o2', 'o1']);

    await repo.clear(TradeEnv.testnet);
    expect((await repo.getOrders(TradeEnv.testnet)).isEmpty, isTrue);
  });

  test('max size clamp keeps newest (trim to 20)', () async {
    final repo = OrderHistoryRepository.instance;
    await repo.clear(TradeEnv.testnet);
    for (var i = 0; i < 150; i++) {
      await repo.addOrder(
        Order(
          id: 'o$i',
          symbol: 'S${i % 3}',
          side: 'BUY',
          quoteQty: i.toDouble(),
          status: 'NEW',
          env: TradeEnv.testnet,
          ts: DateTime.fromMillisecondsSinceEpoch(i),
        ),
      );
    }
    final all = await repo.getOrders(TradeEnv.testnet);
    expect(all.length <= 20, isTrue);
    expect(all.first.id, 'o149'); // newest
  });
}
