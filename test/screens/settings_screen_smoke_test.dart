import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen builds without exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    // ecranul există
    expect(find.byType(SettingsScreen), findsOneWidget);
    // nu s-au aruncat excepții în build
    expect(tester.takeException(), isNull);
  });
}


