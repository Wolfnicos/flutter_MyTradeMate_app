import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/ui/kit/ui_skeleton.dart';

void main() {
  testWidgets('UiSkeleton renders without overflow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UiSkeleton())));
    expect(find.byType(UiSkeleton), findsOneWidget);
  });
}


