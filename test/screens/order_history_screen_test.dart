import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/order_history.dart';
import 'package:mytrademate/screens/order_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OrderHistoryScreen renders two orders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = OrderHistoryRepository.instance;
    await repo.addOrder(Order(
      id: '1',
      symbol: 'BTCUSDT',
      side: 'BUY',
      quoteQty: 100.0,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(100),
    ));
    await repo.addOrder(Order(
      id: '2',
      symbol: 'ETHUSDT',
      side: 'SELL',
      quoteQty: 50.0,
      status: 'FILLED',
      env: TradeEnv.testnet,
      ts: DateTime.fromMillisecondsSinceEpoch(200),
    ));

    await tester.pumpWidget(const MaterialApp(home: OrderHistoryScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('BTCUSDT'), findsOneWidget);
    expect(find.textContaining('ETHUSDT'), findsOneWidget);
  });
}



