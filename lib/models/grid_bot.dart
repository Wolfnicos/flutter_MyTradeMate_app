/// Model pentru Spot Grid Bot (Binance 2025 style)
class GridBot {
  final String id;
  final String symbol; // ex: BNB/ETH
  final double minPrice;
  final double maxPrice;
  final int gridCount;
  final double investment; // total invested
  final DateTime createdAt;
  final GridBotStatus status;
  final GridBotStats stats;

  const GridBot({
    required this.id,
    required this.symbol,
    required this.minPrice,
    required this.maxPrice,
    required this.gridCount,
    required this.investment,
    required this.createdAt,
    required this.status,
    required this.stats,
  });

  double get priceRange => maxPrice - minPrice;
  double get gridStep => priceRange / gridCount;
  double get profitPerGrid => (gridStep / minPrice) * 100; // %
}

enum GridBotStatus {
  running,
  paused,
  stopped,
}

class GridBotStats {
  final Duration executionTime;
  final int totalTransactions;
  final int transactions24h;
  final double roi; // %
  final double pnlUsd;
  final List<GridTransaction> recentTransactions;

  const GridBotStats({
    required this.executionTime,
    required this.totalTransactions,
    required this.transactions24h,
    required this.roi,
    required this.pnlUsd,
    required this.recentTransactions,
  });
}

class GridTransaction {
  final DateTime timestamp;
  final String type; // BUY/SELL
  final double price;
  final double quantity;
  final double value;

  const GridTransaction({
    required this.timestamp,
    required this.type,
    required this.price,
    required this.quantity,
    required this.value,
  });
}

/// Configurație pentru crearea unui Grid Bot nou
class GridBotConfig {
  final String symbol;
  final double minPrice;
  final double maxPrice;
  final int gridCount;
  final double investment;
  final GridMode mode;
  final bool autoRestart;

  const GridBotConfig({
    required this.symbol,
    required this.minPrice,
    required this.maxPrice,
    required this.gridCount,
    required this.investment,
    this.mode = GridMode.geometric,
    this.autoRestart = false,
  });

  bool validate() {
    if (minPrice >= maxPrice) return false;
    if (gridCount < 2 || gridCount > 200) return false;
    if (investment < 10) return false;
    return true;
  }

  String? get validationError {
    if (minPrice >= maxPrice) return 'Min price must be less than max price';
    if (gridCount < 2) return 'Grid count must be at least 2';
    if (gridCount > 200) return 'Grid count cannot exceed 200';
    if (investment < 10) return 'Minimum investment is 10 USDT';
    return null;
  }
}

enum GridMode {
  arithmetic, // linear spacing
  geometric, // exponential spacing (recommended for volatile assets)
}


