import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  PaperBroker broker() => PaperBroker(
        ExchangeRulesForTest.forTest(
          minNotional: 1.0,
          qtyStep: 0.01,
          priceTick: 0.01,
        ),
      );

  test('cancel NEW LIMIT → CANCELED (no fills)', () async {
    final b = broker();
    final id = await b.placeOrder(PaperOrderReq.limit(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      quantity: 0.01,
      price: 1000.0,
      allowPartial: true,
    ));
    // No ticks yet → NEW
    await b.cancelOrder(id);
    final ord = b.orders[id]!;
    expect(ord.status, OrderStatus.canceled);
    expect(ord.filledQty, 0);
  }, skip: true);

  test('partial then cancel → keeps partial fill, cancels remainder', () async {
    final b = broker();
    b.setLastPriceForTest(999.0); // below limit → fill possible
    final id = await b.placeOrder(PaperOrderReq.limit(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      quantity: 1.0,
      price: 1000.0,
      allowPartial: true,
    ));
    // Simulate a partial fill tick
    b.setPartialFillFractionForTest(0.4);
    await b.onTickForTest(symbol: 'BTCUSDT', last: 995.0);

    var ord = b.orders[id]!;
    expect(ord.status, OrderStatus.partiallyFilled);
    expect(ord.filledQty, closeTo(0.4, 1e-9));

    // Cancel remainder
    await b.cancelOrder(id);
    ord = b.orders[id]!;
    expect(ord.status, OrderStatus.canceled);
    expect(ord.filledQty, closeTo(0.4, 1e-9));
  }, skip: true);

  test('cancel FILLED → no-op', () async {
    final b = broker();
    b.setLastPriceForTest(999.0);
    final id = await b.placeOrder(PaperOrderReq.market(
      symbol: 'BTCUSDT',
      side: OrderSide.buy,
      quantity: 0.02,
    ));
    // MARKET executes immediately on last price
    final ord1 = b.orders[id]!;
    expect(ord1.status, OrderStatus.filled);

    await b.cancelOrder(id); // should be no-op
    final ord2 = b.orders[id]!;
    expect(ord2.status, OrderStatus.filled);
  }, skip: true);

  test('cancel OCO leg → peer leg auto-canceled', () async {
    final b = broker();
    // Create OCO (stub: place the pair and retrieve their ids)
    final pair = b.place(PaperOrderReq.ocoSell(
      symbol: 'BTCUSDT',
      quantity: 1.0,
      limitPrice: 1100.0,
      stopPrice: 900.0,
    ));
    final limitId = (pair as PlacedOco).limitId;
    final stopId = pair.stopId;

    await b.cancelOrder(limitId);
    final limit = b.orders[limitId]!;
    final stop = b.orders[stopId]!;
    expect(limit.status, OrderStatus.canceled);
    expect(stop.status, OrderStatus.canceled);
  }, skip: true);
}


