import 'dart:io';

import '../ai/entities.dart';
import '../services/ohlcv_service.dart';

/// Loads historical candles either from Binance (via OHLCVService) or CSV.
class HistoricalDataLoader {
  final OHLCVService service;
  HistoricalDataLoader(this.service);

  Future<List<Candle>> fromExchange(String symbol, {String interval = '5m', int limit = 1000}) async {
    final klines = await service.fetchCandles(symbol, interval: interval, limit: limit);
    return klines;
  }

  /// CSV format: timestamp,open,high,low,close,volume
  Future<List<Candle>> fromCsv(String path) async {
    final f = File(path);
    final lines = await f.readAsLines();
    final out = <Candle>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(',');
      final ts = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]));
      out.add(Candle(
        time: ts,
        open: double.parse(parts[1]),
        high: double.parse(parts[2]),
        low: double.parse(parts[3]),
        close: double.parse(parts[4]),
        volume: double.parse(parts[5]),
      ));
    }
    return out;
  }
}


