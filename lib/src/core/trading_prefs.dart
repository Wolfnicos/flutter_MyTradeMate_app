import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

enum TradeEnv { testnet, live }

class TradingPrefs {
  static const _kApiKey = 'api_key';
  static const _kSecret = 'api_secret';
  static const _kEnv = 'trade_env';
  static const _kFixedQuote = 'fixed_quote'; // USDT per ordin (double)
  static const _kDefaultQuoteCcy = 'default_quote_ccy'; // e.g., 'USDT' (testing convenience)

  final SharedPreferences _sp;
  TradingPrefs._(this._sp);

  static Future<TradingPrefs> load() async =>
      TradingPrefs._(await SharedPreferences.getInstance());

  // Optional CI/runtime overrides via --dart-define
  static const String _envApiKey = String.fromEnvironment('BINANCE_API_KEY', defaultValue: '');
  static const String _envApiSecret = String.fromEnvironment('BINANCE_API_SECRET', defaultValue: '');
  static const String _envEnv = String.fromEnvironment('BINANCE_ENV', defaultValue: 'testnet');
  static const String _envDefaultQuote = String.fromEnvironment('DEFAULT_QUOTE', defaultValue: '');

  String? get apiKey {
    final v = _sp.getString(_kApiKey);
    if (v != null && v.isNotEmpty) return v;
    return _envApiKey.isEmpty ? null : _envApiKey;
  }

  String? get apiSecret {
    final v = _sp.getString(_kSecret);
    if (v != null && v.isNotEmpty) return v;
    return _envApiSecret.isEmpty ? null : _envApiSecret;
  }

  TradeEnv get env {
    final i = _sp.getInt(_kEnv);
    if (i != null) return TradeEnv.values[i];
    final e = _envEnv.toLowerCase();
    return e == 'live' ? TradeEnv.live : TradeEnv.testnet;
  }

  double get fixedQuote {
    final v = _sp.getDouble(_kFixedQuote);
    if (v != null) return v;
    final parsed = double.tryParse(_envDefaultQuote);
    return parsed ?? 50.0;
  }

  Future<void> save({
    String? apiKey,
    String? apiSecret,
    TradeEnv? env,
    double? fixedQuote,
  }) async {
    if (apiKey != null) await _sp.setString(_kApiKey, apiKey);
    if (apiSecret != null) await _sp.setString(_kSecret, apiSecret);
    if (env != null) await _sp.setInt(_kEnv, env.index);
    if (fixedQuote != null) await _sp.setDouble(_kFixedQuote, fixedQuote);
  }

  bool get hasCreds => (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);

  // ────────────────────────────────────────────────────────────────────────────
  // Testing helpers (pure wrappers around SharedPreferences)

  @visibleForTesting
  static Future<TradingPrefs> inMemoryForTest() async {
    return TradingPrefs._(await SharedPreferences.getInstance());
  }

  @visibleForTesting
  Future<void> setApiKey(String v) async => _sp.setString(_kApiKey, v);

  @visibleForTesting
  Future<String?> getApiKey() async => _sp.getString(_kApiKey);

  @visibleForTesting
  Future<void> setApiSecret(String v) async => _sp.setString(_kSecret, v);

  @visibleForTesting
  Future<String?> getApiSecret() async => _sp.getString(_kSecret);

  @visibleForTesting
  Future<void> setEnv(String v) async {
    final norm = v.trim().toLowerCase();
    final e = (norm == 'live') ? TradeEnv.live : TradeEnv.testnet;
    await _sp.setInt(_kEnv, e.index);
  }

  @visibleForTesting
  Future<String> getEnv() async {
    final idx = _sp.getInt(_kEnv) ?? 0;
    return TradeEnv.values[idx] == TradeEnv.live ? 'live' : 'testnet';
  }

  @visibleForTesting
  Future<void> setDefaultQuote(String ccy) async {
    final q = ccy.trim().toUpperCase();
    if (q.isEmpty) return;
    await _sp.setString(_kDefaultQuoteCcy, q);
  }

  @visibleForTesting
  Future<String?> getDefaultQuote() async => _sp.getString(_kDefaultQuoteCcy);
}

@visibleForTesting
Future<TradingPrefs> inMemoryTradingPrefsForTest() async {
  return TradingPrefs._(await SharedPreferences.getInstance());
}




