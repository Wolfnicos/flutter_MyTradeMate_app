import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mytrademate/screens/market_details_screen.dart';
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/services/price_rest_client.dart';

class FakeMarketDataService implements MarketDataService {
  final Map<String, StreamController<double>> _controllers =
      <String, StreamController<double>>{};
  double _last = 1000.0;
  bool _paused = false;

  StreamController<double> _ensure(String symbol) => _controllers.putIfAbsent(
      symbol, () => StreamController<double>.broadcast());

  @override
  Stream<double> streamFor(String symbol) {
    final c = _ensure(symbol);
    // Emit an initial value soon after attach so UI has something to render
    // even if start(...) wasn't explicitly awaited.
    Future.microtask(() {
      if (!_paused && !c.isClosed) {
        c.add(_last);
      }
    });
    return c.stream;
  }

  @override
  Stream<double> prices(String symbol) => streamFor(symbol);

  @override
  Future<void> startSymbol(String symbol) async {
    _ensure(symbol);
    // emit initial value so UI can render non-loading
    if (!_paused) _controllers[symbol]!.add(_last);
  }

  @override
  Future<void> stopSymbol(String symbol) async {}

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
  }

  @override
  Future<void> pause() async {
    _paused = true;
  }

  @override
  Future<void> resume() async {
    _paused = false;
  }

  @override
  Future<double> refreshNow(String symbol) async {
    _last += 1.0;
    if (!_paused) _controllers[symbol]?.add(_last);
    return _last;
  }

  // convenience methods from interface
  @override
  Future<void> start(String symbol) => startSymbol(symbol);

  @override
  Future<void> stopIfOrphan(String symbol) => stopSymbol(symbol);
}

Widget wrapWithMarketData(Widget child,
    {MarketDataService? svc, PaperBroker? broker}) {
  final service = svc ?? FakeMarketDataService();
  return InheritedMarketData(
    service: service,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (_) => child is MarketDetailsScreen
            ? MarketDetailsScreen(
                symbol: child.symbol,
                forTest: true,
                loadDataFn: child.loadDataFn,
                reloadFn: child.reloadFn,
                showAICard: child.showAICard,
                broker: broker,
              )
            : child,
      ),
    ),
  );
}

// Drain microtasks to flush timers/streams after dispose in tests
Future<void> drainMicrotasks([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future.microtask(() {});
  }
}

// Pump event queue helper for pure Dart tests or as an extra flush after dispose
Future<void> pumpEventQueue({int times = 5}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// Leak sentry: drain event loop (timers/streams) after disposing resources
Future<void> drainLeakSentry([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// Deterministic fakes for services tests
class TestFakeEventSource implements PriceEventSource {
  final List<StreamController<dynamic>> _controllers =
      <StreamController<dynamic>>[];
  int connects = 0;

  @override
  Stream<dynamic> connectFromSymbol(String symbol, {required bool testnet}) {
    final uri = Uri.parse('wss://example.com/ws');
    return connect(uri);
  }

  @override
  Stream connect(Uri _) {
    connects++;
    final c = StreamController<dynamic>.broadcast();
    _controllers.add(c);
    return c.stream;
  }

  void emitNum(double v) {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      _controllers.last.add('{"c":$v}');
    }
  }

  @override
  Future<void> close() async {
    if (_controllers.isNotEmpty && !_controllers.last.isClosed) {
      await _controllers.last.close();
    }
  }
}

class TestFakeRest implements PriceRestClient {
  double next;
  TestFakeRest(this.next);
  @override
  Future<bool> ping() async => true;
  @override
  Future<double> tickerPrice(String symbol) async => next;
}
