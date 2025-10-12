import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/trading_modal.dart';

void main() {
  testWidgets(
      'TradingModal disables confirm with invalid amount and enables with valid',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TradingModal(
            assetSymbol: 'BTC/USDT', isBuying: true, initialPrice: 50000),
      ),
    );

    // Initially amount is 0 -> button disabled
    final btn = find.widgetWithText(ElevatedButton, 'Confirm Buy');
    expect(btn, findsOneWidget);
    ElevatedButton eb = tester.widget(btn);
    expect(eb.onPressed, isNull);

    // Enter valid amount
    final field = find.byType(TextField);
    await tester.enterText(field, '100');
    await tester.pumpAndSettle();

    eb = tester.widget(btn);
    expect(eb.onPressed, isNotNull);
  });
}
