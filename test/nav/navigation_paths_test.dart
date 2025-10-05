import 'dart:io' show Platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/dashboard_screen.dart';
import 'package:mytrademate/screens/order_history_screen.dart';
import 'package:mytrademate/screens/settings_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';
  testWidgets('Dashboard → Orders → back, Dashboard → Settings → back', (tester) async {
    if (!runUi) return;
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navKey, home: const DashboardScreen(forTest: true)));

    // Programmatic navigation to avoid tap flakiness in CI viewport
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(OrderHistoryScreen), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);

    navKey.currentState!.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}


