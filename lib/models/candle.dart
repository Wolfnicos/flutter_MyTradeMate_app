class Candle {
  final DateTime openTime;
  final double open, high, low, close, volume;

  Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  static Candle fromBinanceKline(List<dynamic> k) {
    return Candle(
      openTime: DateTime.fromMillisecondsSinceEpoch((k[0] as num).toInt()),
      open: (k[1] as num).toDouble(),
      high: (k[2] as num).toDouble(),
      low: (k[3] as num).toDouble(),
      close: (k[4] as num).toDouble(),
      volume: (k[5] as num).toDouble(),
    );
  }
}
