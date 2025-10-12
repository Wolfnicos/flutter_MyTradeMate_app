import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/dashboard_screen.dart';

void main() {
  // CI safety: this smoke boots live timers/WS; run only with RUN_UI=1 and RUN_DASHBOARD_SMOKE=1
  final runUi = Platform.environment['RUN_UI'] == '1' &&
      Platform.environment['RUN_DASHBOARD_SMOKE'] == '1';
  testWidgets('DashboardScreen builds', (tester) async {
    if (!runUi) return;
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    expect(find.text('MyTradeMate'), findsOneWidget);
  });
}
