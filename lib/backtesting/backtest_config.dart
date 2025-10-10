class BacktestConfig {
  final String symbol;
  final String interval; // e.g., '5m'
  final double initialCapital;
  final int window; // lookback window size (e.g., 64)
  final int horizon; // outcome horizon (candles ahead)

  // Trading frictions
  final double feeRate; // 0.001 = 0.1%
  final double slippageRate; // 0.0005 = 0.05%
  final double maxRiskPerTrade; // 0.02 = 2%

  const BacktestConfig({
    required this.symbol,
    required this.interval,
    this.initialCapital = 10000.0,
    this.window = 64,
    this.horizon = 1,
    this.feeRate = 0.001,
    this.slippageRate = 0.0005,
    this.maxRiskPerTrade = 0.02,
  });
}


