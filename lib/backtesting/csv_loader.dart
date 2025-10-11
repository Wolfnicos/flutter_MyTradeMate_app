import 'dart:io';
import 'package:mytrademate/ai/entities.dart';

class CsvLoader {
  /// Load candles from CSV file.
  /// Supported formats (with or without header):
  /// - timestamp,open,high,low,close,volume (timestamp in ms or ISO8601)
  /// - time,open,high,low,close,volume
  static List<Candle> load(String path, {int? limit}) {
    final file = File(path);
    if (!file.existsSync()) {
      return <Candle>[];
    }
    final lines = file.readAsLinesSync();
    final candles = <Candle>[];
    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 5) continue;

      // Skip obvious header lines
      if (parts[0].toLowerCase().contains('time') ||
          parts[0].toLowerCase().contains('timestamp')) {
        continue;
      }

      DateTime? time;
      final p0 = parts[0].trim();
      // Try parse integer (ms or s)
      final asInt = int.tryParse(p0);
      if (asInt != null) {
        final ts = asInt > 1e12 ? asInt : asInt * 1000; // assume seconds if small
        time = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();
      } else {
        // Try ISO8601
        time = DateTime.tryParse(p0)?.toLocal();
      }
      if (time == null) continue;

      double _num(String s) => double.tryParse(s.trim()) ?? 0.0;
      final open = _num(parts[1]);
      final high = _num(parts[2]);
      final low = _num(parts[3]);
      final close = _num(parts[4]);
      final volume = parts.length > 5 ? _num(parts[5]) : 0.0;

      candles.add(Candle(time: time, open: open, high: high, low: low, close: close, volume: volume));
    }

    if (candles.isEmpty) return candles;

    // Ensure sorted by time
    candles.sort((a, b) => a.time.compareTo(b.time));
    if (limit != null && limit > 0 && candles.length > limit) {
      return candles.sublist(candles.length - limit);
    }
    return candles;
  }
}


