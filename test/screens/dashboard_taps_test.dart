import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/dashboard_screen.dart';
import 'package:mytrademate/screens/order_history_screen.dart';
import 'package:mytrademate/screens/settings_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';

  testWidgets('Dashboard taps navigate or show snackbar', (tester) async {
    if (!runUi) {
      return; // skip in CI unless RUN_UI=1
    }
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    // Orders -> navigates
    await tester.scrollUntilVisible(find.byKey(const Key('dash.orders')), 200.0);
    await tester.tap(find.byKey(const Key('dash.orders')), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(OrderHistoryScreen), findsOneWidget);

    // back
    Navigator.of(tester.element(find.byType(OrderHistoryScreen))).pop();
    await tester.pumpAndSettle();

    // Explain -> snackbar
    await tester.scrollUntilVisible(find.byKey(const Key('dash.explain')), 200.0);
    await tester.tap(find.byKey(const Key('dash.explain')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SnackBar), findsOneWidget);

    // Settings -> navigates
    await tester.scrollUntilVisible(find.byKey(const Key('dash.settings')), 200.0);
    await tester.tap(find.byKey(const Key('dash.settings')), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}


