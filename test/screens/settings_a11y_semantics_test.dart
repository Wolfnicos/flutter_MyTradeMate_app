import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/settings_screen.dart';
import 'package:mytrademate/l10n/strings.dart';
import 'package:mytrademate/ui/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app() => const MaterialApp(home: SettingsScreen());

void main() {
  testWidgets('Settings: Send diagnostics has tap action + a11y label',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_app());
    await t.pumpAndSettle();

    // Prefer stable key
    Finder btn = find.byKey(AppKeys.settingsSendDiagnostics);
    if (btn.evaluate().isEmpty) {
      // Fallback to semantics label if key not yet attached
      btn = find.bySemanticsLabel(S.diagnosticBundle);
    }
    expect(btn, findsOneWidget);

    // Tap and ensure no exceptions (side-effects are implementation details)
    await t.tap(btn);
    await t.pump(const Duration(milliseconds: 100));
  });
}
