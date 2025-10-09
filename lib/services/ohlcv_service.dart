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
      
      final klines = await client.klines(feedSymbol, interval, limit: limit);
      
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
}

