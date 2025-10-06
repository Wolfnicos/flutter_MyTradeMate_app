import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/widgets/sparkline.dart';

void main() {
  testWidgets('Sparkline renders with given values', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Sparkline(values: [1, 2, 3, 2, 4, 3]),
      ),
    ));
    expect(find.byType(Sparkline), findsOneWidget);
  });
}

