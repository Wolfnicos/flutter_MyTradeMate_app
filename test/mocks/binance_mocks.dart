import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mytrademate/services/ai_service.dart' show BinanceClientLike;
import 'package:mytrademate/services/price_stream.dart' show PriceEventSource;

/// Scripted WebSocket event source that replays fixture events deterministically.
/// Each event is a Map with optional keys:
/// - 'c': price value (num or string)
/// - 'delayMs': delay before emitting this event
/// - 'error': string to emit as error
/// - 'close': true to close the stream (simulate disconnect)
class ScriptedEventSource implements PriceEventSource {
  final List<Map<String, dynamic>> _script;
  int _idx = 0; // persists across reconnects
  final List<StreamController<dynamic>> _controllers =
      <StreamController<dynamic>>[];
  int connects = 0;
  int? maxReconnects;
  Duration reconnectBackoff = const Duration(milliseconds: 200);
  Completer<void> _drained = Completer<void>();
  Future<void> get drained => _drained.future;
  int get connectionAttempts => connects;
  bool _ended = false;

  ScriptedEventSource(this._script);

  static Future<ScriptedEventSource> fromFixture(String path) async {
    final file = File(path);
    final text = await file.readAsString();
    final raw = jsonDecode(text) as List<dynamic>;
    final script = raw
        .map<Map<String, dynamic>>(
            (e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    return ScriptedEventSource(script);
  }

  @override
  Stream connect(Uri _) {
    if (_ended) {
      final c = StreamController<dynamic>.broadcast();
      scheduleMicrotask(() async {
        if (!c.isClosed) await c.close();
      });
      _controllers.add(c);
      return c.stream;
    }
    connects += 1;
    if (maxReconnects != null && connects > (1 + maxReconnects!)) {
      final c = StreamController<dynamic>.broadcast();
      // simulate immediate close/failure to connect
      scheduleMicrotask(() async {
        if (!c.isClosed) await c.close();
      });
      _controllers.add(c);
      return c.stream;
    }
    final c = StreamController<dynamic>.broadcast();
    c.onCancel = () {
      if (!c.isClosed) {
        // ignore: discarded_futures
        c.close();
      }
    };
    _controllers.add(c);
    if (connects > 1 && reconnectBackoff > Duration.zero) {
      Future<void>.delayed(reconnectBackoff, () => _run(c));
    } else {
      _run(c);
    }
    return c.stream;
  }

  Future<void> _run(StreamController<dynamic> c) async {
    while (!c.isClosed && !_ended && _idx < _script.length) {
      final ev = _script[_idx++];
      final delayMs = (ev['delayMs'] is num)
          ? (ev['delayMs'] as num).toInt()
          : (ev['delay_ms'] is num)
              ? (ev['delay_ms'] as num).toInt()
              : 0;
      if (delayMs > 0)
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (c.isClosed || _ended) break;
      if (ev['end'] == true) {
        _ended = true;
        await c.close();
        break;
      }
      if (ev['error'] != null) {
        c.addError(ev['error'].toString());
        continue;
      }
      if (ev['close'] == true) {
        await c.close();
        break;
      }
      dynamic price = ev['c'];
      if (price == null && ev['tick'] is Map) {
        final t = ev['tick'] as Map;
        price = t['c'];
      }
      if (price != null) {
        final pStr = price is num ? price.toString() : price.toString();
        c.add('{"c":$pStr}');
      }
    }
    if ((_idx >= _script.length || _ended) && !_drained.isCompleted) {
      _drained.complete();
    }
  }

  @override
  Future<void> close() async {
    _ended = true;
    for (final c in _controllers) {
      if (!c.isClosed) await c.close();
    }
    _controllers.clear();
  }

  void reset() {
    _idx = 0;
    connects = 0;
    _drained = Completer<void>();
    for (final c in _controllers) {
      if (!c.isClosed) {
        // ignore: discarded_futures
        c.close();
      }
    }
    _controllers.clear();
  }
}

/// Mock for REST/HTTP Binance client with programmable responses.
class BinanceClientMock implements BinanceClientLike {
  double _tickerPrice = 1000.0;
  Map<String, dynamic> _ticker24h = const {
    'lastPrice': 1000.0,
    'prevClosePrice': 999.0
  };
  List<List<num>> _klines = const <List<num>>[];

  // Failure scripts
  Exception? nextTickerPriceError;
  Exception? nextTicker24hError;
  Exception? nextKlinesError;

  void setTickerPrice(double v) => _tickerPrice = v;
  void setTicker24h(
      {required double lastPrice, required double prevClosePrice}) {
    _ticker24h = {'lastPrice': lastPrice, 'prevClosePrice': prevClosePrice};
  }

  void setKlinesFromCloses(List<double> closes) {
    // Minimal kline rows: [openTime, open, high, low, close, volume]
    _klines = List<List<num>>.generate(closes.length, (i) {
      final c = closes[i];
      return <num>[i * 60000, c, c, c, c, 1];
    });
  }

  @override
  Future<double> tickerPrice(String symbol) async {
    if (nextTickerPriceError != null) {
      final e = nextTickerPriceError!;
      nextTickerPriceError = null;
      throw e;
    }
    return _tickerPrice;
  }

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async {
    if (nextTicker24hError != null) {
      final e = nextTicker24hError!;
      nextTicker24hError = null;
      throw e;
    }
    return _ticker24h;
  }

  @override
  Future<List<List<num>>> klines(String symbol, String interval,
      {int limit = 200}) async {
    if (nextKlinesError != null) {
      final e = nextKlinesError!;
      nextKlinesError = null;
      throw e;
    }
    return _klines;
  }
}
