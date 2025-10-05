import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen builds without exceptions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}


