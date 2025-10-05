import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ui/explain_page.dart' as expl;
import 'package:mytrademate/services/ai_service.dart';

void main() {
  testWidgets('ExplainPage renders core fields', (tester) async {
    final data = ExplainData(
      symbol: 'BTCUSDT',
      probUp: 0.56,
      nextReturn: 0.01,
      volatility: 0.05,
      volatilityLabel: 'MEDIUM',
      features: List.generate(64, (_) => [0.0, 1.0, 2.0, 3.0]),
    );

    await tester.pumpWidget(MaterialApp(home: expl.ExplainPage(data: data)));
    expect(find.textContaining('Explain BTCUSDT'), findsOneWidget);
    expect(find.textContaining('Prob↑'), findsOneWidget);
    expect(find.textContaining('Volatility'), findsOneWidget);
  });
}


