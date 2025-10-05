import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/dashboard_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';
  testWidgets('DashboardScreen builds', (tester) async {
    if (!runUi) return;
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    expect(find.text('MyTradeMate'), findsOneWidget);
  });
}


