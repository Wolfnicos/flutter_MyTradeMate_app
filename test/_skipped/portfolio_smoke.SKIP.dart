import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/portfolio_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';
  testWidgets('PortfolioScreen builds', (tester) async {
    if (!runUi) return;
    await tester.pumpWidget(const MaterialApp(home: PortfolioScreen()));
    expect(find.text('Portfolio'), findsOneWidget);
  });
}
