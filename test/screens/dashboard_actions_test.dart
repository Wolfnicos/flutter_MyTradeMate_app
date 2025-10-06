import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/dashboard_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';
  testWidgets('Dashboard tile taps navigate or show snackbar', (tester) async {
    if (!runUi) return;
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    // Portfolio tile navigates
    final portfolio = find.byKey(const Key('dash.portfolio'));
    expect(portfolio, findsOneWidget);
    await tester.scrollUntilVisible(portfolio, 200.0);
    await tester.tap(portfolio);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Portfolio'), findsWidgets);

    // Back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Orders tile navigates
    final orders = find.byKey(const Key('dash.orders'));
    await tester.scrollUntilVisible(orders, 200.0);
    await tester.tap(orders);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('Order'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Explain shows snackbar
    final explain = find.byKey(const Key('dash.explain'));
    await tester.scrollUntilVisible(explain, 200.0);
    await tester.tap(explain);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Explain is available from AI cards'), findsOneWidget);
  });
}
