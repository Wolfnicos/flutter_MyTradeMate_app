import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/market_screen.dart';

void main() {
  final runUi = Platform.environment['RUN_UI'] == '1';
  testWidgets('MarketScreen builds without exceptions', (tester) async {
    if (!runUi) return;
    await tester.pumpWidget(const MaterialApp(home: MarketScreen()));
    expect(find.byType(MarketScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}


