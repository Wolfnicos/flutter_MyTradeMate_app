// Lightweight Binance REST client built on Dio.
// Supports testnet/mainnet, unsigned and signed endpoints,
// and common helpers (klines, ticker24h, new order, account).

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:dio/dio.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv, TradingPrefs;
import 'package:mytrademate/services/price_cache.dart';

class DioBinanceClient {
  final Dio _dio;
  final String? apiKey;
  final String? secretKey;
  final TradeEnv env;
  final PriceCache? priceCache;

  DioBinanceClient({
    required this.env,
    this.apiKey,
    this.secretKey,
    this.priceCache,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration receiveTimeout = const Duration(seconds: 20),
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: env == TradeEnv.testnet
                ? 'https://testnet.binance.vision'
                : 'https://api.binance.com',
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
            // Binance returns JSON
            responseType: ResponseType.json,
            // All signed requests need this header
            headers: apiKey != null ? {'X-MBX-APIKEY': apiKey} : null,
          ),
        );

  @visibleForTesting
  factory DioBinanceClient.fakeForTest() {
    return DioBinanceClient(env: TradeEnv.testnet);
  }

  /// Creates a client from saved trading preferences.
  /// For now defaults to TESTNET if prefs are unavailable.
  static Future<DioBinanceClient> createFromPrefs({PriceCache? priceCache}) async {
    try {
      // If TradingPrefs has a real loader, use it; otherwise this falls back to testnet.
      // final prefs = await TradingPrefs.load();
      // return DioBinanceClient(
      //   env: prefs.env,
      //   apiKey: prefs.apiKey,
      //   secretKey: prefs.secretKey,
      // );
      return DioBinanceClient(env: TradeEnv.testnet, priceCache: priceCache);
    } catch (_) {
      return DioBinanceClient(env: TradeEnv.testnet, priceCache: priceCache);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Basic utilities
  String _normSymbol(String s) => s
      .replaceAll('/', '')
      .replaceAll(RegExp(r'\s+'), '')
      .toUpperCase();

  @visibleForTesting
  String normSymbolForTest(String s) => _normSymbol(s);

  @visibleForTesting
  bool supportsSymbolForTest(List<String> listed, String symbol) {
    final s = _normSymbol(symbol);
    return listed.map((e) => _normSymbol('$e')).contains(s);
  }

  String _toQuery(Map<String, dynamic> params) {
    final entries = params.entries.where((e) => e.value != null);
    return entries.map((e) => '${Uri.encodeQueryComponent(e.key)}='
        '${Uri.encodeQueryComponent('${e.value}')}').join('&');
  }

  Map<String, String> toQueryForTest(Map<String, dynamic> q) {
    final out = <String, String>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (!_isPrimitiveQueryValueForTest(v)) return;
      out[k] = '$v';
    });
    return out;
  }

  static bool _isPrimitiveQueryValueForTest(Object? v) =>
      v is num || v is bool || v is String;

  /// Public wrapper for tests (library-visible name; no underscore).
  static bool isPrimitiveQueryValueForTest(Object? v) =>
      _isPrimitiveQueryValueForTest(v);

  @visibleForTesting
  static double stepSizeFromExchangeInfoForTest(Map payload, String symbol) {
    final syms = (payload['symbols'] as List?) ?? const [];
    for (final s in syms) {
      final sym = (s['symbol'] ?? '').toString();
      if (sym.toUpperCase() != symbol.toUpperCase()) continue;
      final filters = (s['filters'] as List?) ?? const [];
      for (final f in filters) {
        if ((f as Map)['filterType'] == 'LOT_SIZE') {
          final v = f['stepSize'];
          if (v is num) return v.toDouble();
          final parsed = double.tryParse('$v');
          return parsed ?? 0.0;
        }
      }
    }
    return 0.0;
  }

  @visibleForTesting
  static double tickSizeFromExchangeInfoForTest(Map payload, String symbol) {
    final syms = (payload['symbols'] as List?) ?? const [];
    for (final s in syms) {
      final sym = (s['symbol'] ?? '').toString();
      if (sym.toUpperCase() != symbol.toUpperCase()) continue;
      final filters = (s['filters'] as List?) ?? const [];
      for (final f in filters) {
        if ((f as Map)['filterType'] == 'PRICE_FILTER') {
          final v = f['tickSize'];
          if (v is num) return v.toDouble();
          final parsed = double.tryParse('$v');
          return parsed ?? 0.0;
        }
      }
    }
    return 0.0;
  }

  String _sign(String message) {
    if (secretKey == null || secretKey!.isEmpty) {
      throw StateError('Signed endpoint requested without secretKey');
    }
    final key = utf8.encode(secretKey!);
    final bytes = utf8.encode(message);
    final h = crypto.Hmac(crypto.sha256, key);
    return h.convert(bytes).toString();
  }

  Never _rethrowDio(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;
      final msg = data is Map && data['msg'] != null ? ' ${data['msg']}' : '';
      throw Exception('Binance HTTP${code != null ? ' $code' : ''}: ${error.type}$msg');
    }
    throw Exception(error.toString());
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
  }) async {
    try {
      final qp = <String, dynamic>{...?query};
      if (signed) {
        qp['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        qp['recvWindow'] = 5000;
        final qs = _toQuery(qp);
        qp['signature'] = _sign(qs);
      }
      final res = await _dio.get(path, queryParameters: qp);
      return res.data;
    } catch (e) {
      _rethrowDio(e);
    }
  }

  Future<dynamic> _post(
    String path, {
    Map<String, dynamic>? query,
    bool signed = false,
  }) async {
    try {
      final qp = <String, dynamic>{...?query};
      if (signed) {
        qp['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        qp['recvWindow'] = 5000;
        final qs = _toQuery(qp);
        qp['signature'] = _sign(qs);
      }
      // Binance accepts signed params as query string for POST
      final res = await _dio.post(path, queryParameters: qp);
      return res.data;
    } catch (e) {
      _rethrowDio(e);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Public API wrappers (subset)

  /// GET /api/v3/ping
  Future<bool> ping() async {
    await _get('/api/v3/ping');
    return true;
  }

  /// GET /api/v3/ticker/24hr
  Future<Map<String, dynamic>> ticker24h(String symbol) async {
    final data = await _get('/api/v3/ticker/24hr', query: {
      'symbol': _normSymbol(symbol),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// GET /api/v3/ticker/price
  Future<double> tickerPrice(String symbol) async {
    final data = await _get('/api/v3/ticker/price', query: {
      'symbol': _normSymbol(symbol),
    });
    final m = Map<String, dynamic>.from(data as Map);
    return parseTickerPriceForTest(m);
  }

  /// Cached price accessor suitable for portfolio and UI usage
  Future<double> getPrice(String symbol) async {
    final s = _normSymbol(symbol);
    final cached = priceCache?.get(s);
    if (cached != null) return cached;
    final p = await tickerPrice(s);
    priceCache?.put(s, p);
    return p;
  }

  /// GET /api/v3/klines
  Future<List<List<num>>> klines(
    String symbol,
    String interval, {
    int limit = 200,
  }) async {
    final data = await _get('/api/v3/klines', query: {
      'symbol': _normSymbol(symbol),
      'interval': interval,
      'limit': limit,
    });
    final raw = parseKlinesForTest(data);
    // Coerce to numeric where possible for runtime callers
    return raw.map<List<num>>((row) {
      final r = List.from(row);
      List<num> out = [];
      for (final v in r) {
        if (v is num) {
          out.add(v);
        } else {
          final parsed = num.tryParse('$v');
          if (parsed != null) {
            out.add(parsed);
          } else {
            out.add(0);
          }
        }
      }
      return out;
    }).toList();
  }

  /// GET /api/v3/exchangeInfo (optionally filter single symbol)
  Future<Map<String, dynamic>> exchangeInfo({String? symbol}) async {
    final data = await _get('/api/v3/exchangeInfo',
        query: symbol != null ? {'symbol': _normSymbol(symbol)} : null);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Returns true if a symbol exists on the current environment
  Future<bool> supportsSymbol(String symbol) async {
    try {
      final info = await exchangeInfo(symbol: symbol);
      final symbols = (info['symbols'] as List?) ?? const [];
      return symbols.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Signed: GET /api/v3/account
  Future<Map<String, dynamic>> account() async {
    final data = await _get('/api/v3/account', signed: true);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Parses account balances to a lightweight list of maps {asset, free, locked}
  /// Keeps only positive totals (free + locked > 0)
  @visibleForTesting
  List<Map<String, dynamic>> parseBalancesForTest(Map<String, dynamic> accountJson) {
    final balances = (accountJson['balances'] as List?) ?? const [];
    final out = <Map<String, dynamic>>[];
    for (final b in balances) {
      final m = Map<String, dynamic>.from(b as Map);
      final asset = (m['asset'] ?? '').toString();
      final free = double.tryParse('${m['free']}') ?? 0.0;
      final locked = double.tryParse('${m['locked']}') ?? 0.0;
      if (free + locked <= 0) continue;
      out.add({'asset': asset, 'free': free, 'locked': locked});
    }
    return out;
  }

  /// Helper to convert balances to holdings with prices
  @visibleForTesting
  List<Map<String, dynamic>> toHoldingsForTest(
    List<Map<String, dynamic>> balances,
    Map<String, double> prices,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final b in balances) {
      final asset = (b['asset'] ?? '').toString().toUpperCase();
      final free = (b['free'] as num).toDouble();
      final locked = (b['locked'] as num).toDouble();
      final total = free + locked;
      if (asset == 'USDT') {
        out.add({'asset': asset, 'qty': total, 'valueUsdt': total});
        continue;
      }
      final pair = '${asset}USDT';
      final p = prices[pair];
      if (p == null) continue; // ignore unknowns for now
      out.add({'asset': asset, 'qty': total, 'valueUsdt': total * p});
    }
    return out;
  }

  /// Lightweight connectivity check — try a cheap public endpoint
  Future<bool> testConnection() async {
    try {
      await tickerPrice('BTCUSDT');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Signed: POST /api/v3/order (MARKET by quote qty)
  Future<Map<String, dynamic>> newMarketOrderQuote({
    required String symbol,
    required String side, // BUY / SELL
    required num quoteOrderQty,
  }) async {
    final data = await _post('/api/v3/order', signed: true, query: {
      'symbol': _normSymbol(symbol),
      'side': side.toUpperCase(),
      'type': 'MARKET',
      'quoteOrderQty': quoteOrderQty,
      'newOrderRespType': 'RESULT',
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Convenience wrapper compatible with older call sites
  Future<Map<String, dynamic>> newOrderMarketDouble({
    required String symbol,
    required String side,
    required double quoteQty,
  }) async {
    return newMarketOrderQuote(symbol: symbol, side: side, quoteOrderQty: quoteQty);
  }

  /// Signed: POST /api/v3/order (LIMIT GTC)
  Future<Map<String, dynamic>> newLimitOrder({
    required String symbol,
    required String side, // BUY / SELL
    required num quantity,
    required num price,
    String timeInForce = 'GTC',
  }) async {
    final data = await _post('/api/v3/order', signed: true, query: {
      'symbol': _normSymbol(symbol),
      'side': side.toUpperCase(),
      'type': 'LIMIT',
      'timeInForce': timeInForce,
      'quantity': quantity,
      'price': price,
      'newOrderRespType': 'RESULT',
    });
    return Map<String, dynamic>.from(data as Map);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Helpers

  /// Returns minNotional (or 0) from exchangeInfo filters for a symbol
  Future<double> minNotional(String symbol) async {
    final info = await exchangeInfo(symbol: symbol);
    final symbols = (info['symbols'] as List?) ?? const [];
    if (symbols.isEmpty) return 0.0;
    final filters = (symbols.first['filters'] as List?) ?? const [];
    for (final f in filters) {
      final m = f as Map;
      final t = m['filterType'];
      if (t == 'NOTIONAL' || t == 'MIN_NOTIONAL') {
        final v = m['minNotional'] ?? m['notional'];
        if (v != null) return double.tryParse('$v') ?? 0.0;
      }
    }
    return 0.0;
  }

  /// Clamps a quote amount up to min notional if needed
  Future<num> clampQuoteToMinNotional(String symbol, num quote) async {
    final min = await minNotional(symbol);
    if (min <= 0) return quote;
    final q = quote.toDouble();
    return q < min ? min : q;
  }

  @visibleForTesting
  static num clampToMinNotionalForTest({required num quote, required num minNotional}) {
    if (quote >= minNotional) return quote;
    return minNotional;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Parsers exposed for testing

  @visibleForTesting
  double parseTickerPriceForTest(Map<String, dynamic> r) {
    final v = (r['price'] ?? r['c']);
    return v is num ? v.toDouble() : double.parse('$v');
  }

  @visibleForTesting
  List<List<dynamic>> parseKlinesForTest(dynamic data) {
    if (data is! List) return <List<dynamic>>[];
    return data
        .map<List<dynamic>>((row) => row is List ? row.cast<dynamic>() : <dynamic>[])
        .toList();
  }

  /// Extract MIN_NOTIONAL threshold from a raw exchangeInfo JSON map
  @visibleForTesting
  static num minNotionalFromExchangeInfoForTest(
    Map<String, dynamic> json,
    String symbol,
  ) {
    final syms = (json['symbols'] as List?) ?? const [];
    Map entry = const {};
    for (final e in syms) {
      final m = e as Map;
      final s = (m['symbol'] ?? '').toString().toUpperCase();
      if (s == symbol.toUpperCase()) {
        entry = m;
        break;
      }
    }
    final filters = (entry['filters'] as List?) ?? const [];
    for (final f in filters) {
      final m = f as Map;
      if (m['filterType'] == 'MIN_NOTIONAL') {
        final v = m['minNotional'];
        if (v is num) return v;
        return num.parse('$v');
      }
    }
    return 0;
  }
}