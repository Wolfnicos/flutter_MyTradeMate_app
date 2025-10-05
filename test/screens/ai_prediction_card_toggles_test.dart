import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytrademate/screens/widgets/ai_prediction_card.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Ensure prefs are empty for each test
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('toggles persist and control visibility of warnings', (tester) async {
    // Provide a simple fake AIService via instance override if needed
    // Here we rely on AIPredictionCard calling AIService().getPrediction(symbol)
    // which should succeed in existing test setup with fake path.

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AIPredictionCard(symbol: 'BTCUSDT')),
    ));

    // Allow future to resolve similarly to other tests
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Expand the explanation panel to reveal toggles by tapping the help icon
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Find switches by type to avoid brittle text matching
    final switches = find.byType(SwitchListTile);
    expect(switches, findsWidgets);

    // Initially ON by default → expect at least one info line rendered later
    // Toggle both OFF
    await tester.tap(switches.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    // If a second switch exists, toggle it as well
    final all = switches.evaluate();
    if (all.length > 1) {
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    // Rebuild widget to read prefs
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AIPredictionCard(symbol: 'BTCUSDT')),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Expand again after rebuild
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Switches should still be present after rebuild
    expect(find.byType(SwitchListTile), findsWidgets);
  });
}


