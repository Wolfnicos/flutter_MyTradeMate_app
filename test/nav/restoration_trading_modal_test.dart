import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/trading_modal.dart';

void main() {
  testWidgets('TradingModal restores amount after state restoration',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      restorationScopeId: 'app',
      home: TradingModal(
          assetSymbol: 'BTCUSDT', isBuying: true, initialPrice: 1000),
    ));

    await tester.enterText(find.byKey(tradeAmountFieldKey), '0.123');
    await tester.pump(const Duration(milliseconds: 16));

    await tester.restartAndRestore();

    await tester.pump();
    expect(find.text('0.123'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
