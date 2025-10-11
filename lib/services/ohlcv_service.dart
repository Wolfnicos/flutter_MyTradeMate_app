import 'package:flutter/foundation.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/services/symbol_mapper.dart';

/// OHLCVService - Fetch candle data pentru AI predictions
/// Converts Binance klines → List<Candle>
/// Always returns List (empty dacă eroare), never null!
class OHLCVService {
  final DioBinanceClient client;

  OHLCVService(this.client);

  /// Fetch candles pentru un symbol (UI symbol, va fi normalizat)
  /// Returns empty list dacă symbol nu e disponibil (NEVER null!)
  /// 
  /// interval: '1m', '5m', '15m', '1h', '4h', '1d'
  /// limit: câte candles (max 1000 pe Binance)
  /// forceQuote: forțează USDT chiar dacă UI arată EUR/USD
  Future<List<Candle>> fetchCandles(
    String uiSymbol, {
    String interval = '5m',
    int limit = 100,
    bool forceQuote = true,
  }) async {
    try {
      // Normalizează simbolul la USDT (Binance default)
      final feedSymbol = forceQuote 
          ? SymbolMapper.mapUiToFeed(uiSymbol, quote: 'USDT')
          : uiSymbol;
      
      debugPrint('📊 Fetching candles: $uiSymbol → $feedSymbol ($interval x$limit)');
      
      // Binance limit per call is up to 1000 for klines. For >1000, batch by time.
      final target = limit;
      final batch = target > 1000 ? 1000 : target;
      int remaining = target;
      int? endTime; // ms
      final all = <List<num>>[];
      while (remaining > 0) {
        final take = remaining > batch ? batch : remaining;
        final data = await client.klines(
          feedSymbol,
          interval,
          limit: take,
          endTime: endTime,
        );
        if (data.isEmpty) break;
        all.insertAll(0, data); // prepend older chunks at front later
        // Prepare next page: set endTime to first kline openTime - 1
        final firstTs = (data.first[0] as num).toInt();
        endTime = firstTs - 1;
        remaining -= data.length;
        if (data.length < take) break; // nothing more
      }
      final klines = all.isEmpty
          ? await client.klines(feedSymbol, interval, limit: limit)
          : all;
      
      if (klines.isEmpty) {
        debugPrint('⚠️ No candles returned for $feedSymbol');
        return <Candle>[];
      }
      
      final candles = klines.map((kline) {
        // Binance klines format:
        // [timestamp, open, high, low, close, volume, closeTime, ...]
        return Candle(
          time: DateTime.fromMillisecondsSinceEpoch(
            kline[0] is int 
                ? kline[0] as int 
                : ((kline[0]).toInt()),
          ),
          open: _toDouble(kline[1]),
          high: _toDouble(kline[2]),
          low: _toDouble(kline[3]),
          close: _toDouble(kline[4]),
          volume: _toDouble(kline[5]),
        );
      }).toList();
      
      debugPrint('✅ Fetched ${candles.length} candles for $feedSymbol');
      // If insufficient and interval != '5m', try resampling from lower timeframe
      if (candles.length < limit && interval != '5m') {
        final resampled = await _fallbackResample(
          uiSymbol: feedSymbol,
          targetInterval: interval,
          targetLimit: limit,
          forceQuote: false,
        );
        if (resampled.isNotEmpty) {
          debugPrint('↩️ Resampled ${resampled.length} candles for $feedSymbol ($interval)');
          return resampled;
        }
      }
      return candles;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch candles for $uiSymbol: $e');
      return <Candle>[]; // ALWAYS return empty list, never null!
    }
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Factory pentru a crea din prefs
  static Future<OHLCVService> createFromPrefs() async {
    final client = await DioBinanceClient.createFromPrefs();
    return OHLCVService(client);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Resampling helpers
  Future<List<Candle>> _fallbackResample({
    required String uiSymbol,
    required String targetInterval,
    required int targetLimit,
    required bool forceQuote,
  }) async {
    // Map higher TF to factor relative to 5m
    int factor5m(String itv) {
      switch (itv) {
        case '15m': return 3;
        case '1h': return 12;
        case '4h': return 48;
        case '1d': return 288;
        default: return 1;
      }
    }
    Duration tfDuration(String itv) {
      switch (itv) {
        case '5m': return const Duration(minutes: 5);
        case '15m': return const Duration(minutes: 15);
        case '1h': return const Duration(hours: 1);
        case '4h': return const Duration(hours: 4);
        case '1d': return const Duration(days: 1);
        default: return const Duration(minutes: 5);
      }
    }

    // For 1d, resample directly from 5m to avoid extra 1h fetch chatter

    final factor = factor5m(targetInterval);
    if (factor <= 1) return <Candle>[];
    final need5m = targetLimit * factor;
    final cap5m = 50000; // hard cap
    final req5m = need5m > cap5m ? cap5m : need5m;
    final base5m = await fetchCandles(uiSymbol, interval: '5m', limit: req5m, forceQuote: forceQuote);
    if (base5m.isEmpty) return <Candle>[];
    final out = _resample(base5m, tfDuration(targetInterval));
    return out.take(targetLimit).toList();
  }

  List<Candle> _resample(List<Candle> base, Duration tf) {
    if (base.isEmpty) return <Candle>[];
    base.sort((a, b) => a.time.compareTo(b.time));
    final out = <Candle>[];
    DateTime bucketStart = _floorTime(base.first.time, tf);
    double open = base.first.open;
    double high = base.first.high;
    double low = base.first.low;
    double close = base.first.close;
    double volume = base.first.volume;

    void push() {
      out.add(Candle(time: bucketStart, open: open, high: high, low: low, close: close, volume: volume));
    }

    for (int i = 1; i < base.length; i++) {
      final c = base[i];
      final bStart = _floorTime(c.time, tf);
      if (bStart == bucketStart) {
        // same bucket, aggregate
        if (c.high > high) high = c.high;
        if (c.low < low) low = c.low;
        close = c.close;
        volume += c.volume;
      } else {
        // close previous
        push();
        // start new bucket
        bucketStart = bStart;
        open = c.open;
        high = c.high;
        low = c.low;
        close = c.close;
        volume = c.volume;
      }
    }
    // push last
    push();
    return out;
  }

  DateTime _floorTime(DateTime t, Duration d) {
    final ms = d.inMilliseconds;
    final ts = t.millisecondsSinceEpoch;
    final floored = (ts ~/ ms) * ms;
    return DateTime.fromMillisecondsSinceEpoch(floored).toLocal();
  }
}

