class Holding {
  final String asset;
  final double qty;
  final double priceUsdt;
  const Holding(this.asset, this.qty, this.priceUsdt);
}

class PortfolioSnapshot {
  final List<Holding> holdings;
  final double totalUsdt;
  final double dailyPnl;
  const PortfolioSnapshot(this.holdings, this.totalUsdt, {this.dailyPnl = 0.0});

  PortfolioSnapshot copyWith(
          {List<Holding>? holdings, double? totalUsdt, double? dailyPnl}) =>
      PortfolioSnapshot(holdings ?? this.holdings, totalUsdt ?? this.totalUsdt,
          dailyPnl: dailyPnl ?? this.dailyPnl);
}

class PortfolioAggregator {
  /// Computes total USDT using [prices] map like { 'BTCUSDT': 60000.0, 'ETHUSDT': 3000.0 }.
  /// - Assets not in [prices] are ignored to keep deterministic behavior
  /// - USDT counts at face value via price 1.0
  static List<Holding> toHoldingsFromBalances(List<Map> balances) {
    final out = <Holding>[];
    for (final b in balances) {
      final asset = (b['asset'] ?? '').toString().toUpperCase();
      var free = double.tryParse('${b['free']}') ?? 0.0;
      var locked = double.tryParse('${b['locked']}') ?? 0.0;
      if (!free.isFinite) free = 0.0;
      if (!locked.isFinite) locked = 0.0;
      final qty = free + locked;
      if (asset.isEmpty || !qty.isFinite || qty <= 0) continue;
      final price = asset == 'USDT' ? 1.0 : 0.0;
      out.add(Holding(asset, qty, price));
    }
    return out;
  }

  static PortfolioSnapshot compute(
      List<Holding> holdings, Map<String, double> prices) {
    final enriched = holdings.map((h) {
      final p = h.asset == 'USDT' ? 1.0 : (prices[h.asset] ?? 0.0);
      return Holding(h.asset, h.qty, p);
    }).toList();
    final total = enriched.fold<double>(0.0, (s, h) => s + h.qty * h.priceUsdt);
    return PortfolioSnapshot(enriched, total);
  }
}

// Test-only helper for summing total USDT value of holdings
// Does not affect runtime behavior; kept under @visibleForTesting via import site
double sumUsdtForTest(Iterable<Holding> holdings) =>
    holdings.fold(0.0, (s, e) => s + e.qty * e.priceUsdt);
