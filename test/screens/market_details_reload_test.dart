import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/market_details_screen.dart';
import '../_helpers/test_market_data.dart';

Future<void> pumpABit(WidgetTester t, {int ticks = 4}) async {
  for (var i = 0; i < ticks; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('MarketDetails shows progress during reload (offline DI)',
      (tester) async {
    bool reloaded = false;
    Future<void> load() async {}
    Future<void> reload() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      reloaded = true;
    }

    await tester.pumpWidget(wrapWithMarketData(MaterialApp(
      home: MarketDetailsScreen(
        symbol: 'BTCUSDT',
        loadDataFn: load,
        reloadFn: reload,
        showAICard: false,
      ),
    )));

    await tester.tap(find.byKey(marketReloadBtnKey));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);

    await pumpABit(tester, ticks: 4);
    expect(reloaded, isTrue);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
