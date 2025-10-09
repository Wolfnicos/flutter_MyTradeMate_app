import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ui/kit/ui_market_skeleton.dart';
import 'package:mytrademate/ui/kit/ui_market_error.dart';

void main() {
  testWidgets('UiMarketSkeleton builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UiMarketSkeleton())));
    expect(find.byType(UiMarketSkeleton), findsOneWidget);
  });

  testWidgets('UiMarketError shows retry', (tester) async {
    bool retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiMarketError(message: 'Oops', onRetry: () => retried = true),
      ),
    ));
    expect(find.text('Oops'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}



