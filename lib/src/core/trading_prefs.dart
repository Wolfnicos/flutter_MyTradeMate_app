import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

enum TradeEnv { testnet, live }

class TradingPrefs {
  static const _kHasSeenDisclaimer = 'has_seen_disclaimer_v1';
  static const _kApiKey = 'api_key';
  static const _kSecret = 'api_secret';
  static const _kEnv = 'trade_env';
  static const _kFixedQuote = 'fixed_quote'; // USDT per ordin (double)
  static const _kDefaultQuoteCcy =
      'default_quote_ccy'; // e.g., 'USDT' (testing convenience)
  static const _kTelemetryOptIn = 'telemetry_opt_in_v1';
  // SignalPolicy-related keys
  static const _kUserConsentTrading = 'user_consent_trading';
  static const _kMinConfidence = 'policy_min_confidence'; // 0..100
  static const _kCooldownSec = 'policy_cooldown_seconds';
  static const _kMaxTradesPerDay = 'policy_max_trades_per_day';
  static const _kBuyThreshold = 'policy_buy_threshold'; // 0..1
  static const _kSellThreshold = 'policy_sell_threshold'; // 0..1
  static const _kHystUp =
      'policy_hysteresis_up'; // 0..1 (added to buy threshold)
  static const _kHystDown =
      'policy_hysteresis_down'; // 0..1 (subtracted from sell threshold)
  static const _kQuotePerTrade =
      'policy_quote_per_trade'; // in quote ccy (e.g. USDT)
  static const _kPaperTrading = 'paper_trading_mode'; // bool

  final SharedPreferences _sp;
  TradingPrefs._(this._sp);

  static Future<TradingPrefs> load() async =>
      TradingPrefs._(await SharedPreferences.getInstance());

  // Optional CI/runtime overrides via --dart-define
  static const String _envApiKey =
      String.fromEnvironment('BINANCE_API_KEY', defaultValue: '');
  static const String _envApiSecret =
      String.fromEnvironment('BINANCE_API_SECRET', defaultValue: '');
  static const String _envEnv =
      String.fromEnvironment('BINANCE_ENV', defaultValue: 'testnet');
  static const String _envDefaultQuote =
      String.fromEnvironment('DEFAULT_QUOTE', defaultValue: '');

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

  Future<bool> isPaperTrading() async {
    return _sp.getBool(_kPaperTrading) ?? false;
  }

  Future<void> setPaperTrading(bool enabled) async {
    await _sp.setBool(_kPaperTrading, enabled);
  }

  Future<void> save({
    String? apiKey,
    String? apiSecret,
    TradeEnv? env,
    double? fixedQuote,
    bool? paperTrading,
  }) async {
    if (apiKey != null) await _sp.setString(_kApiKey, apiKey);
    if (apiSecret != null) await _sp.setString(_kSecret, apiSecret);
    if (env != null) await _sp.setInt(_kEnv, env.index);
    if (fixedQuote != null) await _sp.setDouble(_kFixedQuote, fixedQuote);
    if (paperTrading != null) await _sp.setBool(_kPaperTrading, paperTrading);
  }

  bool get hasCreds =>
      (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);

  // ────────────────────────────────────────────────────────────────────────────
  // SignalPolicy persisted settings with sensible defaults

  Future<void> setUserConsentTrading(bool v) async {
    await _sp.setBool(_kUserConsentTrading, v);
  }

  Future<bool> getUserConsentTrading() async {
    return _sp.getBool(_kUserConsentTrading) ?? false;
  }

  Future<void> setMinConfidence(double v) async {
    await _sp.setDouble(_kMinConfidence, v);
  }

  Future<double> getMinConfidence() async {
    return _sp.getDouble(_kMinConfidence) ?? 0.0;
  }

  Future<void> setCooldown(Duration d) async {
    await _sp.setInt(_kCooldownSec, d.inSeconds);
  }

  Future<Duration> getCooldown() async {
    final s = _sp.getInt(_kCooldownSec);
    return Duration(seconds: s ?? 0);
  }

  Future<void> setMaxTradesPerDay(int n) async {
    await _sp.setInt(_kMaxTradesPerDay, n);
  }

  Future<int> getMaxTradesPerDay() async {
    return _sp.getInt(_kMaxTradesPerDay) ?? 0;
  }

  Future<void> setThresholds(
      {required double buy,
      required double sell,
      double hystUp = 0.0,
      double hystDown = 0.0}) async {
    await _sp.setDouble(_kBuyThreshold, buy);
    await _sp.setDouble(_kSellThreshold, sell);
    await _sp.setDouble(_kHystUp, hystUp);
    await _sp.setDouble(_kHystDown, hystDown);
  }

  Future<(double buy, double sell, double hystUp, double hystDown)>
      getThresholds() async {
    final buy = _sp.getDouble(_kBuyThreshold) ?? 0.55;
    final sell = _sp.getDouble(_kSellThreshold) ?? 0.45;
    final up = _sp.getDouble(_kHystUp) ?? 0.0;
    final down = _sp.getDouble(_kHystDown) ?? 0.0;
    return (buy, sell, up, down);
  }

  Future<void> setQuotePerTrade(double v) async {
    await _sp.setDouble(_kQuotePerTrade, v);
  }

  Future<double> getQuotePerTrade() async {
    final v = _sp.getDouble(_kQuotePerTrade);
    if (v != null) return v;
    // Default to fixedQuote if set, else 25
    final fq = _sp.getDouble(_kFixedQuote);
    return fq ?? 25.0;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Disclaimer (paper-trading) acknowledgement

  Future<bool> hasSeenDisclaimer() async {
    return _sp.getBool(_kHasSeenDisclaimer) ?? false;
  }

  Future<void> markDisclaimerSeen() async {
    await _sp.setBool(_kHasSeenDisclaimer, true);
  }

  // Per-symbol last trade timestamp
  String _kLastTradeAtKey(String symbol) =>
      'lastTradeAt:${symbol.toUpperCase()}';
  String _kTradeCountDayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return 'tradeCount:$y-$m-$d';
  }

  Future<void> setLastTradeAt(String symbol, DateTime t) async {
    await _sp.setString(_kLastTradeAtKey(symbol), t.toIso8601String());
  }

  Future<DateTime?> getLastTradeAt(String symbol) async {
    final v = _sp.getString(_kLastTradeAtKey(symbol));
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  Future<void> incTradeCountForDay(DateTime day) async {
    final k = _kTradeCountDayKey(DateTime(day.year, day.month, day.day));
    final cur = _sp.getInt(k) ?? 0;
    await _sp.setInt(k, cur + 1);
  }

  Future<int> getTradeCountForDay(DateTime day) async {
    final k = _kTradeCountDayKey(DateTime(day.year, day.month, day.day));
    return _sp.getInt(k) ?? 0;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Testing helpers (pure wrappers around SharedPreferences)

  @visibleForTesting
  static Future<TradingPrefs> inMemoryForTest() async {
    return TradingPrefs._(await SharedPreferences.getInstance());
  }

  // Feature flags (test-only helpers)
  @visibleForTesting
  Future<void> setUndoTradeEnabledForTest(bool v) async {
    await _sp.setBool('feature.undo_trade', v);
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

  @visibleForTesting
  Future<void> setDisclaimerSeenForTest(bool v) async {
    await _sp.setBool(_kHasSeenDisclaimer, v);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Telemetry opt-in

  Future<void> setTelemetryOptIn(bool v) async {
    await _sp.setBool(_kTelemetryOptIn, v);
  }

  Future<bool> getTelemetryOptIn() async {
    return _sp.getBool(_kTelemetryOptIn) ?? false;
  }
}

@visibleForTesting
Future<TradingPrefs> inMemoryTradingPrefsForTest() async {
  return TradingPrefs._(await SharedPreferences.getInstance());
}
