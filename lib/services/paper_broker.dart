import 'dart:collection';
/*
PaperBroker — deterministic offline execution simulator

Supported order types:
- MARKET: executes immediately at the last tick price (taker fees)
- LIMIT: fills when the candle wick crosses the limit price (maker fees); price-time not modeled
- STOP (market): arms when wick crosses stop; executes as MARKET on next tick (taker)
- STOP_LIMIT: arms on stop; then fills like LIMIT when price crosses limit
- OCO (sell): paired LIMIT and STOP legs; filling one cancels the peer leg
- TRAILING STOP (sell/buy): tracks peak (sell: high, buy: low) and triggers when last crosses (peak ± trail)

Wick trigger model:
- Each tick is a candle with high/low/close; triggers and fills check if limit/stop is within [low, high]
- STOP triggers set a flag to execute on the next tick as MARKET

Partial fills:
- Deterministic partial fraction can be enabled via cfg.partialFillFraction (0..1]; by default full fill
- LIMIT and STOP_LIMIT are treated as maker; MARKET/STOP are taker

OCO behavior:
- On fill of one leg, the peer leg is cancelled immediately and removed

Precision and min notional:
- Price/qty rounding and MIN_NOTIONAL validation come from ExchangeRules in cfg.rulesBySymbol
- MIN_NOTIONAL is enforced at placement (throws PaperOrderReject); no auto-clamp on fill
*/
import 'package:mytrademate/models/candle.dart' as models show Candle;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mytrademate/services/exchange_rules.dart';

enum OrderSide { buy, sell }

enum OrderType {
  market,
  limit,
  stop,
  stopLimit,
  oco,
  takeProfit,
  stopLoss,
  trailingStop,
}

enum OrderStatus { new_, partiallyFilled, filled, canceled }

class PaperOrder {
  final String id;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final double? price; // limit/stop prices as relevant
  final double? stopPrice; // for stop-limit/oco
  final double qty; // base quantity
  final bool reduceOnly;
  final bool allowPartial;

  // Internal
  double filledQty = 0.0;
  bool active = true;
  bool triggered = false; // for stop/stopLimit awaiting next tick
  OrderStatus status = OrderStatus.new_;
  double? trailPeak; // for trailing stop tracking
  PaperOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.qty,
    this.price,
    this.stopPrice,
    this.reduceOnly = false,
    this.allowPartial = false,
  });
}

class Position {
  final String symbol;
  double qty = 0.0; // base
  double avgPrice = 0.0; // USDT per base
  double realizedPnl = 0.0;
  double feesPaid = 0.0;
  Position(this.symbol);
}

class FillEvent {
  final String orderId;
  final String symbol;
  final double qty;
  final double price;
  final double fee;
  FillEvent(this.orderId, this.symbol, this.qty, this.price, this.fee);
}

class PaperOrderReject implements Exception {
  final String message;
  PaperOrderReject(this.message);
  @override
  String toString() => 'PaperOrderReject: $message';
}

class PaperOrderReq {
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final double quantity;
  final double? price;
  final double? stopPrice;
  final bool allowPartial;
  final String? clientId;

  const PaperOrderReq._({
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    this.price,
    this.stopPrice,
    this.allowPartial = false,
    this.clientId,
  });

  factory PaperOrderReq.market({
    required String symbol,
    required OrderSide side,
    required double quantity,
    bool allowPartial = false,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: side,
        type: OrderType.market,
        quantity: quantity,
        allowPartial: allowPartial,
        clientId: clientId,
      );

  factory PaperOrderReq.limit({
    required String symbol,
    required OrderSide side,
    required double price,
    required double quantity,
    bool allowPartial = false,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: side,
        type: OrderType.limit,
        price: price,
        quantity: quantity,
        allowPartial: allowPartial,
        clientId: clientId,
      );

  factory PaperOrderReq.stopMarket({
    required String symbol,
    required OrderSide side,
    required double stopPrice,
    required double quantity,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: side,
        type: OrderType.stop,
        stopPrice: stopPrice,
        quantity: quantity,
        clientId: clientId,
      );

  factory PaperOrderReq.ocoSell({
    required String symbol,
    required double quantity,
    required double limitPrice,
    required double stopPrice,
    bool stopIsMarket = true,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: OrderSide.sell,
        type: OrderType.oco,
        price: limitPrice,
        stopPrice: stopPrice,
        quantity: quantity,
        clientId: clientId,
      );

  factory PaperOrderReq.trailingStopSell({
    required String symbol,
    required double quantity,
    required double trailAmount,
    double? initialRef,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: OrderSide.sell,
        type: OrderType.trailingStop,
        price: initialRef, // used as initial peak reference if provided
        stopPrice: trailAmount, // reuse stopPrice field as trailing distance
        quantity: quantity,
        clientId: clientId,
      );

  factory PaperOrderReq.stopLimit({
    required String symbol,
    required OrderSide side,
    required double stopPrice,
    required double price,
    required double quantity,
    String? clientId,
  }) =>
      PaperOrderReq._(
        symbol: symbol,
        side: side,
        type: OrderType.stopLimit,
        price: price,
        stopPrice: stopPrice,
        quantity: quantity,
        clientId: clientId,
      );
}

class PaperBrokerConfig {
  final double makerFeeBps; // e.g. 1 = 0.01%
  final double takerFeeBps; // e.g. 4 = 0.04%
  final double slippageBps; // applied to market orders
  final Map<String, ExchangeRules> rulesBySymbol; // precision & minNotional
  final double
      partialFillFraction; // deterministic fraction for partial fills (0..1]

  const PaperBrokerConfig({
    this.makerFeeBps = 1.0,
    this.takerFeeBps = 4.0,
    this.slippageBps = 0.0,
    this.rulesBySymbol = const {},
    this.partialFillFraction = 1.0,
  });
}

/// Deterministic, single-threaded simulator for offline tests.
class PaperBroker {
  final PaperBrokerConfig cfg;
  final Map<String, Position> _positions = <String, Position>{};
  final Map<String, PaperOrder> _orders = <String, PaperOrder>{};
  final Map<String, String?> _ocoLink =
      <String, String?>{}; // orderId -> other leg
  final List<FillEvent> _ledger = <FillEvent>[];
  final Map<String, double> balances = <String, double>{};
  int _seq = 1;
  final DateTime Function() _now;
  final Map<String, double> _lastPrices = <String, double>{};
  double? _partialOverride; // test-only override for partial fill fraction

  PaperBroker(Object? rulesOrCfg,
      {DateTime Function()? now,
      PaperBrokerConfig cfg = const PaperBrokerConfig()})
      : _now = now ?? DateTime.now,
        cfg = (rulesOrCfg is PaperBrokerConfig)
            ? rulesOrCfg
            : (rulesOrCfg is ExchangeRules)
                ? PaperBrokerConfig(
                    makerFeeBps: cfg.makerFeeBps,
                    takerFeeBps: cfg.takerFeeBps,
                    slippageBps: cfg.slippageBps,
                    rulesBySymbol: {
                      ...cfg.rulesBySymbol,
                      'DEFAULT': rulesOrCfg,
                    },
                    partialFillFraction: cfg.partialFillFraction,
                  )
                : cfg;

  UnmodifiableListView<FillEvent> get ledger => UnmodifiableListView(_ledger);
  UnmodifiableMapView<String, PaperOrder> get orders =>
      UnmodifiableMapView(_orders);
  Position position(String symbol) =>
      _positions.putIfAbsent(symbol, () => Position(symbol));

  /// Convenience: simple tick wrapper using last/optional wick
  void tick(String symbol, double last, {double? high, double? low}) {
    _lastPrices[symbol] = last;
    final c = models.Candle(
      openTime: _now(),
      open: last,
      high: high ?? last,
      low: low ?? last,
      close: last,
      volume: 0.0,
    );
    onCandle(c);
  }

  void submit(PaperOrder o, {String? ocoPeerId}) {
    final rules = _rulesFor(o.symbol);
    final clampedQty =
        (rules == null) ? o.qty : roundQtyToStepForTest(o.qty, rules.stepSize);
    final clampedPrice = (rules == null || o.price == null)
        ? o.price
        : roundPriceToTickForTest(o.price!, rules.tickSize);
    final clampedStop = (rules == null || o.stopPrice == null)
        ? o.stopPrice
        : roundPriceToTickForTest(o.stopPrice!, rules.tickSize);
    final order = PaperOrder(
      id: o.id,
      symbol: o.symbol,
      side: o.side,
      type: o.type,
      qty: clampedQty,
      price: clampedPrice,
      stopPrice: clampedStop,
      reduceOnly: o.reduceOnly,
      allowPartial: o.allowPartial,
    );
    _orders[o.id] = order;
    if (ocoPeerId != null) {
      _ocoLink[o.id] = ocoPeerId;
    }
  }

  void cancel(String orderId) {
    final o = _orders[orderId];
    if (o == null) return;
    o.active = false;
    o.status =
        o.filledQty > 0 ? OrderStatus.partiallyFilled : OrderStatus.canceled;
    _orders.remove(orderId);
    final peer = _ocoLink.remove(orderId);
    if (peer != null) _ocoLink.remove(peer);
  }

  dynamic place(PaperOrderReq req, {void Function(FillEvent)? onFill}) {
    final id = req.clientId ?? 'o${_seq++}';
    if (req.type == OrderType.oco) {
      // Create limit leg
      final limitId = id;
      final limit = PaperOrder(
        id: limitId,
        symbol: req.symbol,
        side: OrderSide.sell, // ocoSell only in this helper
        type: OrderType.limit,
        qty: req.quantity,
        price: req.price,
      );
      _orders[limitId] = limit;
      // Validate min notional for limit leg if rules exist
      final r = _rulesFor(limit.symbol);
      if (r != null && limit.price != null) {
        final err = r.validateNotional(price: limit.price!, qty: limit.qty);
        if (err != null) {
          // rollback insert
          _orders.remove(limitId);
          throw PaperOrderReject(err);
        }
      }
      // Create stop leg (market or stop)
      final stopId = 'o${_seq++}';
      final stopType = (req.stopPrice != null && req.price == null)
          ? OrderType.stop
          : OrderType.stop;
      final stop = PaperOrder(
        id: stopId,
        symbol: req.symbol,
        side: OrderSide.sell,
        type: stopType,
        qty: req.quantity,
        stopPrice: req.stopPrice,
      );
      _orders[stopId] = stop;
      _ocoLink[limitId] = stopId;
      _ocoLink[stopId] = limitId;
      return PlacedOco(limitId: limitId, stopId: stopId);
    } else {
      final order = PaperOrder(
        id: id,
        symbol: req.symbol,
        side: req.side,
        type: req.type,
        qty: req.quantity,
        price: req.price,
        stopPrice: req.stopPrice,
        allowPartial: req.allowPartial,
      );
      // Validate min notional for limit/stopLimit at placement time
      final r = _rulesFor(order.symbol);
      if (r != null &&
          (order.type == OrderType.limit ||
              order.type == OrderType.stopLimit)) {
        final px = order.price ?? 0.0;
        final err = r.validateNotional(price: px, qty: order.qty);
        if (err != null) {
          throw PaperOrderReject(err);
        }
      }
      _orders[id] = order;
      // Market orders execute immediately at last known price (taker)
      if (order.type == OrderType.market) {
        final last = _lastPrices[order.symbol];
        if (last != null) {
          final px = _applySlippage(last);
          _fill(order, px, order.qty, taker: true);
          // Mark filled and remove
          order.status = OrderStatus.filled;
          _orders.remove(order.id);
        }
      }
      return order;
    }
  }

  /// Process a candle tick: use wick (high/low) to activate stops and fills.
  void onCandle(models.Candle c) {
    // Copy keys to avoid concurrent modification while iterating
    final orderIds = List<String>.from(_orders.keys);
    for (final id in orderIds) {
      final o = _orders[id];
      if (o == null || !o.active) continue;
      _tryFill(o, c);
      if (o.filledQty >= o.qty - 1e-12) {
        _closeOrder(o);
      }
    }
  }

  void _tryFill(PaperOrder o, models.Candle c) {
    if (!o.active) return;
    if (o.status == OrderStatus.filled || o.status == OrderStatus.canceled)
      return;

    switch (o.type) {
      case OrderType.market:
        _handleMarket(o, c);
        break;
      case OrderType.limit:
        _handleLimit(o, c);
        break;
      case OrderType.stop:
        _handleStop(o, c);
        break;
      case OrderType.stopLimit:
        _handleStopLimit(o, c);
        break;
      case OrderType.oco:
        _handleOco(o, c);
        break;
      case OrderType.takeProfit:
        if (_tpTriggered(o.side, o.price!, c.low, c.high)) {
          _fill(o, o.price!, o.qty - o.filledQty, taker: false);
        }
        break;
      case OrderType.stopLoss:
        if (_stopTriggered(o.side, o.price!, c.low, c.high)) {
          _fill(o, _applySlippage(c.close), o.qty - o.filledQty, taker: true);
        }
        break;
      case OrderType.trailingStop:
        _handleTrailingStop(o, c);
        break;
    }
  }

  void _handleMarket(PaperOrder o, models.Candle c) {
    final qty = o.qty - o.filledQty;
    if (qty <= 0) return;
    _fill(o, _applySlippage(c.close), qty, taker: true);
  }

  void _handleLimit(PaperOrder o, models.Candle c) {
    if (!_crossed(o.side, o.price!, c.low, c.high)) return;
    final remaining = o.qty - o.filledQty;
    if (remaining <= 0) return;
    final pf = _partialOverride ?? cfg.partialFillFraction;
    final allowPartial = o.allowPartial && pf > 0 && pf < 1.0;
    final qty = allowPartial ? remaining * pf : remaining;
    _fill(o, o.price!, qty, taker: false);
  }

  void _handleStop(PaperOrder o, models.Candle c) {
    if (!o.triggered) {
      if (_stopTriggered(o.side, o.stopPrice!, c.low, c.high)) {
        o.triggered = true; // convert to market on next tick
      }
      return;
    }
    final qty = o.qty - o.filledQty;
    if (qty <= 0) return;
    _fill(o, _applySlippage(c.close), qty, taker: true);
  }

  void _handleStopLimit(PaperOrder o, models.Candle c) {
    if (!o.triggered) {
      if (_stopTriggered(o.side, o.stopPrice!, c.low, c.high)) {
        o.triggered = true; // arm limit
      }
      return;
    }
    if (_crossed(o.side, o.price!, c.low, c.high)) {
      final qty = o.qty - o.filledQty;
      if (qty <= 0) return;
      _fill(o, o.price!, qty, taker: false);
    }
  }

  void _handleOco(PaperOrder o, models.Candle c) {
    bool done = false;
    if (_stopTriggered(o.side, o.stopPrice!, c.low, c.high)) {
      _fill(o, _applySlippage(c.close), o.qty - o.filledQty, taker: true);
      done = true;
    } else if (_crossed(o.side, o.price!, c.low, c.high)) {
      _fill(o, o.price!, o.qty - o.filledQty, taker: false);
      done = true;
    }
    if (done) {
      final peer = _ocoLink.remove(o.id);
      if (peer != null) {
        _orders.remove(peer);
        _ocoLink.remove(peer);
      }
    }
  }

  void _handleTrailingStop(PaperOrder o, models.Candle c) {
    final dist = o.stopPrice ?? 0.0;
    if (o.side == OrderSide.sell) {
      o.trailPeak = (o.trailPeak ?? o.price ?? c.close);
      if (c.high > o.trailPeak!) o.trailPeak = c.high;
      final triggerLevel = o.trailPeak! - dist;
      if (!o.triggered) {
        if (c.low <= triggerLevel || c.close <= triggerLevel) {
          o.triggered = true;
        }
      } else {
        final qty = o.qty - o.filledQty;
        if (qty <= 0) return;
        _fill(o, _applySlippage(c.close), qty, taker: true);
      }
    } else {
      o.trailPeak = (o.trailPeak ?? o.price ?? c.close);
      if (c.low < o.trailPeak!) o.trailPeak = c.low;
      final triggerLevel = o.trailPeak! + dist;
      if (!o.triggered) {
        if (c.high >= triggerLevel || c.close >= triggerLevel) {
          o.triggered = true;
        }
      } else {
        final qty = o.qty - o.filledQty;
        if (qty <= 0) return;
        _fill(o, _applySlippage(c.close), qty, taker: true);
      }
    }
  }

  bool _crossed(OrderSide side, double px, double low, double high) {
    return side == OrderSide.buy ? (low <= px) : (high >= px);
  }

  bool _stopTriggered(OrderSide side, double stopPx, double low, double high) {
    return side == OrderSide.buy ? (high >= stopPx) : (low <= stopPx);
  }

  bool _tpTriggered(OrderSide side, double tpPx, double low, double high) {
    return side == OrderSide.buy ? (high >= tpPx) : (low <= tpPx);
  }

  double _applySlippage(double px) =>
      px * (1.0 + (cfg.slippageBps / 10000.0) * 1.0);

  void _fill(PaperOrder o, double px, double qty, {required bool taker}) {
    if (qty <= 0) return;
    final rules = _rulesFor(o.symbol);
    // Do not auto-clamp minNotional; enforce via placement validation instead.
    // Apply deterministic partial fraction when configured (< 1.0)
    final pf = _partialOverride ?? cfg.partialFillFraction;
    if (pf > 0 && pf < 1.0) {
      final remaining = (o.qty - o.filledQty);
      final desired = remaining * pf;
      qty = desired;
    }
    final feeRate = (taker ? cfg.takerFeeBps : cfg.makerFeeBps) / 10000.0;
    final fee = (qty * px).abs() * feeRate;
    o.filledQty += qty;
    o.status = (o.filledQty >= o.qty - 1e-12)
        ? OrderStatus.filled
        : OrderStatus.partiallyFilled;
    final pos = position(o.symbol);
    final (base, quote) = _splitSymbol(o.symbol);
    balances.putIfAbsent(base, () => 0.0);
    balances.putIfAbsent(quote, () => 0.0);
    if (o.side == OrderSide.buy) {
      final newCost = pos.avgPrice * pos.qty + px * qty + fee;
      pos.qty += qty;
      pos.avgPrice = pos.qty <= 1e-12 ? 0.0 : (newCost / pos.qty);
      pos.feesPaid += fee;
      balances[base] = (balances[base] ?? 0.0) + qty;
      balances[quote] = (balances[quote] ?? 0.0) - (px * qty + fee);
    } else {
      // SELL reduces position; realize PnL on sold qty
      final sellProceeds = px * qty - fee;
      final cost = pos.avgPrice * qty;
      pos.qty -= qty;
      pos.realizedPnl += (sellProceeds - cost);
      pos.feesPaid += fee;
      if (pos.qty <= 1e-12) {
        pos.qty = 0.0;
        pos.avgPrice = 0.0;
      }
      balances[base] = (balances[base] ?? 0.0) - qty;
      balances[quote] = (balances[quote] ?? 0.0) + (px * qty - fee);
    }
    _ledger.add(FillEvent(o.id, o.symbol, qty, px, fee));
  }

  void _closeOrder(PaperOrder o) {
    o.active = false;
    // Preserve filled/partial status; only mark canceled if not filled
    if (o.status != OrderStatus.filled &&
        o.status != OrderStatus.partiallyFilled) {
      o.status = OrderStatus.canceled;
    }
    _orders.remove(o.id);
    final peer = _ocoLink.remove(o.id);
    if (peer != null) {
      _orders.remove(peer);
      _ocoLink.remove(peer);
    }
  }

  /// Unrealized PnL at mark price
  double unrealizedPnl(String symbol, double mark) {
    final p = position(symbol);
    return (mark - p.avgPrice) * p.qty;
  }

  /// Sum realized PnL for all symbols quoted in [quote], e.g. 'USDT'.
  double realizedPnlUsdt(String quote) {
    final q = quote.toUpperCase();
    double sum = 0.0;
    for (final e in _positions.entries) {
      final sym = e.key.toUpperCase();
      if (sym.endsWith(q)) {
        sum += e.value.realizedPnl;
      }
    }
    return sum;
  }

  (String, String) _splitSymbol(String symbol) {
    final s = symbol.toUpperCase();
    if (s.endsWith('USDT')) {
      return (s.substring(0, s.length - 4), 'USDT');
    }
    if (s.endsWith('USD')) {
      return (s.substring(0, s.length - 3), 'USD');
    }
    // Fallback: split last 3 as quote
    return (s.substring(0, s.length - 3), s.substring(s.length - 3));
  }

  ExchangeRules? _rulesFor(String symbol) {
    return cfg.rulesBySymbol[symbol] ?? cfg.rulesBySymbol['DEFAULT'];
  }

  // Convenience async-style helpers for UI/tests
  Future<String> placeOrder(PaperOrderReq req) async {
    final res = place(req);
    if (res is PaperOrder) return res.id;
    if (res is PlacedOco) return res.limitId;
    if (res is String) return res;
    return res.toString();
  }

  Future<void> cancelOrder(String orderId) async {
    cancel(orderId);
  }

  // Test-only helpers
  @visibleForTesting
  void setPartialFillFractionForTest(double fraction) {
    _partialOverride = fraction;
  }

  @visibleForTesting
  void setLastPriceForTest(double price, {String symbol = 'BTCUSDT'}) {
    _lastPrices[symbol] = price;
  }

  @visibleForTesting
  Future<void> onTickForTest({
    required String symbol,
    required double last,
    double? high,
    double? low,
  }) async {
    tick(symbol, last, high: high, low: low);
    await Future<void>.value();
  }
}

class PlacedOco {
  final String limitId;
  final String stopId;
  const PlacedOco({required this.limitId, required this.stopId});
}

class PaperOrderView {
  final String id;
  final double quantity;
  final double qtyFilled;
  final OrderStatus status;
  const PaperOrderView(this.id, this.quantity, this.qtyFilled, this.status);
}

class PaperSnapshot {
  final Map<String, PaperOrderView> orderById;
  const PaperSnapshot(this.orderById);
}

extension PaperBrokerSnapshot on PaperBroker {
  PaperSnapshot snapshot(String symbol) {
    final m = <String, PaperOrderView>{};
    for (final e in orders.entries) {
      final o = e.value;
      if (o.symbol != symbol) continue;
      m[o.id] = PaperOrderView(o.id, o.qty, o.filledQty, o.status);
    }
    return PaperSnapshot(m);
  }
}
