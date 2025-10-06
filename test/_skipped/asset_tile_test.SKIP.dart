import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/widgets/asset_tile.dart';

void main() {
  testWidgets('AssetTile renders symbol, price and change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return const AssetTile(
              symbol: 'BTCUSDT',
              name: 'Bitcoin',
              price: '12345.67',
              change: '2.34%',
              isUp: true,
            );
          }),
        ),
      ),
    );

    expect(find.text('BTCUSDT'), findsWidgets);
    expect(find.text('Bitcoin'), findsWidgets);
    expect(find.textContaining('12345.67'), findsWidgets);
    expect(find.text('2.34%'), findsOneWidget);
  });
}
