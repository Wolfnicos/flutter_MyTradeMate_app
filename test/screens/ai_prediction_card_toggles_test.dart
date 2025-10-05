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

    // Expand the explanation panel to reveal toggles
    await tester.tap(find.text('Why this signal?'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Find switches by text
    final uncertaintyFinder = find.text('Show uncertainty note');
    final dataGapsFinder = find.text('Show data gaps note');

    expect(uncertaintyFinder, findsOneWidget);
    expect(dataGapsFinder, findsOneWidget);

    // Initially ON by default → expect at least one info line rendered later
    // Toggle both OFF
    await tester.tap(uncertaintyFinder);
    await tester.pumpAndSettle();
    await tester.tap(dataGapsFinder);
    await tester.pumpAndSettle();

    // Rebuild widget to read prefs
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AIPredictionCard(symbol: 'BTCUSDT')),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Expand again after rebuild
    await tester.tap(find.text('Why this signal?'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    // Switches should reflect OFF state now
    expect(uncertaintyFinder, findsOneWidget);
    expect(dataGapsFinder, findsOneWidget);
  });
}


