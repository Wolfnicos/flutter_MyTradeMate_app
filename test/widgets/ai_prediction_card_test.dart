import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/screens/widgets/ai_prediction_card.dart';
import '../fakes/fake_engine.dart';

void main() {
  testWidgets('AIPredictionCard renders metrics deterministically',
      (tester) async {
    AILocator.I.overrideEngineForTests(FakeEngine());

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AIPredictionCard(symbol: 'BTCUSDT')),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.textContaining('Probability Up'), findsWidgets);
    expect(find.textContaining('Expected Return'), findsWidgets);
    expect(find.textContaining('Volatility'), findsWidgets);
  });
}
