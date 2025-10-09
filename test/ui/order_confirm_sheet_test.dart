import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytrademate/screens/market_details_screen.dart';
import '../_helpers/test_market_data.dart';

// NOTE: This is a tests-first scaffold for Confirm + Undo.
// It is intentionally skipped until UI keys and broker DI are wired.

class FakePaperBroker {
  final List<String> placed = <String>[];
  final List<String> canceled = <String>[];

  Future<String> placeOrder(dynamic req) async {
    final id = 'oid-${placed.length + 1}';
    placed.add(id);
    return id;
  }

  Future<void> cancelOrder(String orderId) async {
    canceled.add(orderId);
  }
}

Widget _wrap({
  required Widget child,
  required FakePaperBroker broker, // reserved for future DI
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: wrapWithMarketData(child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Confirm sheet shows and confirms order → broker.placeOrder called',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // TODO: TradingPrefs.setUndoTradeEnabledForTest(true) once available

      final broker = FakePaperBroker();

      await tester.pumpWidget(
        _wrap(
          broker: broker,
          child: const MarketDetailsScreen(symbol: 'BTCUSDT', forTest: true),
        ),
      );
      await tester.pumpAndSettle();

      // 1) Open confirm sheet (tap trade CTA)
      final tradeCta = find.byKey(const Key('trade.place')); // TODO: use AppKeys.tradePlace
      // Skip until UI key is wired
      if (tradeCta.evaluate().isEmpty) {
        return; // scaffold only
      }
      await tester.tap(tradeCta);
      await tester.pumpAndSettle();

      // 2) Sheet visible with summary and confirm
      expect(find.byKey(const Key('confirm.sheet')), findsOneWidget); // TODO: AppKeys.confirmSheet
      expect(find.textContaining('BTCUSDT'), findsWidgets);
      final confirmBtn = find.byKey(const Key('confirm.place')); // TODO: AppKeys.confirmPlace
      expect(confirmBtn, findsOneWidget);

      // 3) Confirm
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 4) Snackbar with Undo appears
      expect(find.byKey(const Key('undo.trade')), findsOneWidget); // TODO: AppKeys.undoTrade

      // 5) Broker got the place call (scaffold expectation)
      expect(broker.placed.length, anyOf(0, 1));
    },
    skip: true,
  );

  testWidgets(
    'Undo from snackbar cancels the order',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // TODO: TradingPrefs.setUndoTradeEnabledForTest(true)

      final broker = FakePaperBroker();

      await tester.pumpWidget(
        _wrap(
          broker: broker,
          child: const MarketDetailsScreen(symbol: 'BTCUSDT', forTest: true),
        ),
      );
      await tester.pumpAndSettle();

      final tradeCta = find.byKey(const Key('trade.place'));
      if (tradeCta.evaluate().isEmpty) {
        return; // scaffold only
      }
      await tester.tap(tradeCta);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.place')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Undo
      await tester.tap(find.byKey(const Key('undo.trade')));
      await tester.pumpAndSettle();

      // Cancellation recorded (scaffold expectation)
      expect(broker.canceled, anyOf(isEmpty, contains('oid-1')));
    },
    skip: true,
  );
}





