import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/market_details_screen.dart';
import '../_helpers/test_market_data.dart';

Future<void> pumpABit(WidgetTester t, {int ticks = 3}) async {
  for (var i = 0; i < ticks; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('MarketDetails shows loading on reload', (tester) async {
    Future<void> reload() async => Future.microtask(() {});

    await tester.pumpWidget(wrapWithMarketData(MaterialApp(
      home: MarketDetailsScreen(
        symbol: 'BTCUSDT',
        loadDataFn: () async {},
        reloadFn: reload,
        showAICard: false,
      ),
    )));

    await tester.tap(find.byKey(marketReloadBtnKey), warnIfMissed: false);
    await pumpABit(tester, ticks: 3);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}


