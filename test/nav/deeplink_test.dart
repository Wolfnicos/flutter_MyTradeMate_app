import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mytrademate/screens/market_details_screen.dart';
import '../_helpers/test_market_data.dart';

Route<dynamic> _routes(RouteSettings s) {
  if (s.name?.startsWith('/market/') == true) {
    final sym = s.name!.split('/').last;
    return MaterialPageRoute(
        builder: (_) => MarketDetailsScreen(symbol: sym, forTest: true));
  }
  return MaterialPageRoute(builder: (_) => const Placeholder());
}

void main() {
  testWidgets('Deep link /market/BTCUSDT opens MarketDetails', (tester) async {
    await tester.pumpWidget(wrapWithMarketData(const MaterialApp(
        onGenerateRoute: _routes, initialRoute: '/market/BTCUSDT')));
    await tester.pumpAndSettle();
    expect(find.byType(MarketDetailsScreen), findsOneWidget);
    expect(find.textContaining('BTCUSDT'), findsWidgets);
  });
}
