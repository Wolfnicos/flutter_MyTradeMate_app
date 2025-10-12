// Lightweight in-memory price cache with injectable clock (for tests).

typedef NowFn = DateTime Function();

class PriceCache {
  final Map<String, double> _m = {};
  final NowFn _now;
  PriceCache({NowFn? now}) : _now = now ?? DateTime.now;

  double? get(String symbol) => _m[symbol.toUpperCase()];
  void put(String symbol, double price) => _m[symbol.toUpperCase()] = price;
}
