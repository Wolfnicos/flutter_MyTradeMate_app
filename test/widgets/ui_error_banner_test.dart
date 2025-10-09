import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/ui/kit/ui_error_banner.dart';

void main() {
  testWidgets('UiErrorBanner shows message and retry', (tester) async {
    bool retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiErrorBanner(message: 'Oops', onRetry: () => retried = true),
      ),
    ));
    expect(find.text('Oops'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, true);
  });
}


