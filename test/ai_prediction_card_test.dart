import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/widgets/ai_prediction_card.dart';

void main() {
  testWidgets('AIPredictionCard renders loading then error or data', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AIPredictionCard(symbol: 'BTCUSDT')),
    ));
    // Shows loader first
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Let future resolve
    await tester.pumpAndSettle(const Duration(seconds: 1));
    // Either shows card with texts or an error notice; assert widget exists
    expect(find.byType(Card), findsWidgets);
  });
}
