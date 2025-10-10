
/// Trade execution simulator with fees, slippage and risk cap
class TradeSimulator {
  final double feeRate; // e.g., 0.001 (0.1%)
  final double slippageRate; // e.g., 0.0005 (0.05%)
  final double maxRiskPerTrade; // e.g., 0.02 (2%)

  const TradeSimulator({
    this.feeRate = 0.0007,
    this.slippageRate = 0.0003,
    this.maxRiskPerTrade = 0.02,
  });

  /// Simulate BUY: returns (newCapital, positionQty, entryPrice, feePaid)
  (double, double, double, double) buy({
    required double capital,
    required double price,
  }) {
    final budget = capital * maxRiskPerTrade;
    final priceWithSlip = price * (1 + slippageRate);
    final fee = budget * feeRate;
    final qty = (budget - fee) / priceWithSlip;
    final newCapital = capital - budget;
    return (newCapital, qty, priceWithSlip, fee);
  }

  /// Simulate SELL: returns (newCapital, feePaid, pnl)
  (double, double, double) sell({
    required double capital,
    required double positionQty,
    required double entryPrice,
    required double price,
  }) {
    final priceWithSlip = price * (1 - slippageRate);
    final gross = positionQty * priceWithSlip;
    final fee = gross * feeRate;
    final newCapital = capital + (gross - fee);
    final pnl = positionQty * (priceWithSlip - entryPrice);
    return (newCapital, fee, pnl);
  }
}


