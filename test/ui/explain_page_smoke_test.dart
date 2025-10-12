import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ui/explain_page.dart' as expl;
import 'package:mytrademate/ai/explain.dart';

void main() {
  testWidgets('ExplainPage renders core fields', (tester) async {
    final data = ExplainData(
      symbol: 'BTCUSDT',
      asOf: DateTime.utc(2025, 1, 1),
      pBuy: 0.56,
      expReturn: 0.01,
      annVol: 0.05,
      features: List.generate(64, (_) => [0.0, 1.0, 2.0, 3.0]),
      modelRev: 'r-test',
    );

    await tester.pumpWidget(MaterialApp(home: expl.ExplainPage(data: data)));
    expect(find.textContaining('Explain BTCUSDT'), findsOneWidget);
    expect(find.textContaining('Prob↑'), findsOneWidget);
    expect(find.textContaining('Volatility'), findsOneWidget);
  });
}
