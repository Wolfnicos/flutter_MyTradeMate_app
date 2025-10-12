import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytrademate/screens/dashboard_screen.dart';

Widget wrapWithApp(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('First-run disclaimer shows then hides on acknowledge',
      (t) async {
    SharedPreferences.setMockInitialValues({'has_seen_disclaimer_v1': false});
    await t.pumpWidget(wrapWithApp(const DashboardScreen(forTest: true)));
    await t.pump();
    expect(find.byKey(const Key('btnDisclaimerAcknowledge')), findsOneWidget);
    await t.tap(find.byKey(const Key('btnDisclaimerAcknowledge')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('btnDisclaimerAcknowledge')), findsNothing);
  });
}
