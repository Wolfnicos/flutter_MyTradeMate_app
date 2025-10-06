import 'package:flutter/material.dart';
import 'package:mytrademate/ui/keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {double textScale = 1.0, TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(textDirection: dir, child: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  testWidgets('Settings: no overflows at 1.6x/2.0x and key present', (t) async {
    Future<void> pumpWithScale(double scale) async {
      await t.pumpWidget(_wrap(const SettingsScreen(), textScale: scale));
      // Wait until the form list is built (async prefs load)
      for (var i = 0; i < 60; i++) {
        if (find.byType(ListView).evaluate().isNotEmpty) break;
        await t.pump(const Duration(milliseconds: 25));
      }
      // Aggressive scroll attempts to reveal bottom actions regardless of lazy layout
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(ListView).first, const Offset(0, -600));
        await t.pump(const Duration(milliseconds: 50));
        if (find.byKey(AppKeys.settingsSendDiagnostics).evaluate().isNotEmpty) break;
      }
      final diagnostics = find.byKey(AppKeys.settingsSendDiagnostics);
      if (diagnostics.evaluate().isNotEmpty) {
        await t.ensureVisible(diagnostics);
        await t.pumpAndSettle(const Duration(milliseconds: 50));
      }
      // Bounded settle loop to avoid indefinite animations/timeouts
      for (var i = 0; i < 40; i++) {
        if (find.byKey(AppKeys.settingsSendDiagnostics).evaluate().isNotEmpty) break;
        await t.pump(const Duration(milliseconds: 25));
      }
    }
    for (final scale in [1.0, 1.6, 2.0]) {
      await pumpWithScale(scale);
      expect(find.byKey(AppKeys.settingsSendDiagnostics), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('RTL smoke: Settings build and affordances present', (t) async {
    await t.pumpWidget(_wrap(const SettingsScreen(), dir: TextDirection.rtl));
    for (var i = 0; i < 60; i++) {
      if (find.byType(ListView).evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 25));
    }
    for (var i = 0; i < 6; i++) {
      await t.drag(find.byType(ListView).first, const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 50));
      if (find.byKey(AppKeys.settingsSendDiagnostics).evaluate().isNotEmpty) break;
    }
    final diagnostics = find.byKey(AppKeys.settingsSendDiagnostics);
    if (diagnostics.evaluate().isNotEmpty) {
      await t.ensureVisible(diagnostics);
      await t.pumpAndSettle(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 40; i++) {
      if (find.byKey(AppKeys.settingsSendDiagnostics).evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 25));
    }
    expect(find.byKey(AppKeys.settingsSendDiagnostics), findsOneWidget);
  });
}


