import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/widgets/ai_signal_card.dart';

Future<void> pumpABit(WidgetTester t, {int ticks = 3}) async {
  for (var i = 0; i < ticks; i++) {
    await t.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('AiSignalCard renders direction/confidence/return',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AiSignalCard(
            probUp: 0.61, nextReturn: 0.0123, volatility: 0.08, horizon: '1h'),
      ),
    ));

    await pumpABit(tester);
    expect(find.textContaining('AI Prediction'), findsOneWidget);
    expect(find.textContaining('Direction: BUY'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });
}
