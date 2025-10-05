import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/trading_modal.dart';

Future<void> setSurface(
  WidgetTester tester, {
  required Size size,
  double dpr = 3.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Rotate (surface size change) keeps TradingModal field', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      restorationScopeId: 'app',
      home: TradingModal(assetSymbol: 'BTCUSDT', isBuying: true, initialPrice: 1000),
    ));

    // Use a larger logical width to avoid layout overflows in summary row
    await setSurface(tester, size: const Size(1440, 2560), dpr: 2.0);

    await tester.enterText(find.byKey(tradeAmountFieldKey), '0.5');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0.5'), findsOneWidget);

    await setSurface(tester, size: const Size(2560, 1440), dpr: 2.0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0.5'), findsOneWidget);
  });
}


