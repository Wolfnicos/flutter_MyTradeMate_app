import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/trading_modal.dart';

void main() {
  testWidgets('Place button disabled when amount invalid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TradingModal(assetSymbol: 'BTCUSDT', isBuying: true, initialPrice: 50000),
        ),
      ),
    );

    final amountField = find.byKey(tradeAmountFieldKey);
    expect(amountField, findsOneWidget);

    await tester.enterText(amountField, '0');
    await tester.pumpAndSettle();

    final btnWidget = tester.widget<ElevatedButton>(find.byKey(tradeConfirmBtnKey));
    expect(btnWidget.onPressed, isNull);
  });
}


