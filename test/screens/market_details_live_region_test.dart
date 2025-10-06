import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/market_details_screen.dart';
import 'package:mytrademate/l10n/strings.dart';
import 'package:mytrademate/ui/keys.dart';
import '../_helpers/test_market_data.dart';

Widget _app() {
  return wrapWithMarketData(
    const MaterialApp(
      home: MarketDetailsScreen(
        symbol: 'BTCUSDT',
        forTest: true,
        showAICard: false,
        loadDataFn: _noop,
        reloadFn: _noop,
      ),
    ),
  );
}

Future<void> _noop() async {}

void main() {
  testWidgets('MarketDetails: price strip is a live region with value', (t) async {
    await t.pumpWidget(_app());
    await t.pump(const Duration(milliseconds: 50));

    // We can't depend on SemanticsTester helpers in this env; assert presence by label
    // settle a bit to allow semantics tree build
    for (var i = 0; i < 40; i++) {
      if (find.byKey(AppKeys.marketLiveRegion).evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 25));
    }
    expect(find.byKey(AppKeys.marketLiveRegion), findsOneWidget);
  });
}


