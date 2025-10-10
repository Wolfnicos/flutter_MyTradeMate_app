import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/screens/backtest_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run BacktestScreen with ensemble: BTCUSDT / 5m / 7d', (tester) async {
    // Initialize AI to ensure ensemble is available
    await AILocator.I.init();

    // Pump the screen directly
    await tester.pumpWidget(const MaterialApp(home: BacktestScreen()));
    await tester.pumpAndSettle();

    // Open Settings tab first in the new tabbed UI
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Select interval 5m
    final intervalField = find.widgetWithText(DropdownButtonFormField<String>, 'Interval');
    expect(intervalField, findsOneWidget);
    await tester.tap(intervalField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5m').last);
    await tester.pumpAndSettle();

    // Press Run Backtest
    final runText = find.text('Run Backtest');
    expect(runText, findsOneWidget);
    await tester.tap(runText);
    await tester.pump();

    // Wait for computation to finish (network + TFLite). Generous timeout.
    await tester.pumpAndSettle(const Duration(minutes: 5));

    // Print a summary from the UI (presence of results card)
    expect(find.text('Rezultate Backtest'), findsOneWidget);
  });
}


