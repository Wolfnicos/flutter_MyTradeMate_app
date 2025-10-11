import 'package:mytrademate/ai/entities.dart';

/// Trade execution simulator with fees, slippage and risk cap
class TradeSimulator {
  final double feeRate; // e.g., 0.001 (0.1%)
  final double slippageRate; // e.g., 0.0005 (0.05%)
  final double maxRiskPerTrade; // e.g., 0.02 (2%)
  final double stopLossPercent; // e.g., 0.02 = 2%
  final double takeProfitPercent; // e.g., 0.03 = 3%

  const TradeSimulator({
    this.feeRate = 0.0007,
    this.slippageRate = 0.0003,
    this.maxRiskPerTrade = 0.02,
    this.stopLossPercent = 0.02,
    this.takeProfitPercent = 0.03,
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

  /// Simulate a simple SL/TP outcome from entry across future candles.
  /// Returns PnL in quote currency, net of exit fee (and assumes entry fee already accounted elsewhere).
  double simulateTrade({
    required String action, // 'BUY' or 'SELL'
    required double entryPrice,
    required List<Candle> futureCandles,
    required double positionValue, // capital allocated on entry
  }) {
    if (futureCandles.isEmpty) return 0.0;
    final fee = feeRate; // apply on exit only here
    for (final candle in futureCandles) {
      final priceChange = (candle.close - entryPrice) / (entryPrice == 0 ? 1 : entryPrice);
      if (action == 'BUY') {
        if (priceChange <= -stopLossPercent) {
          final loss = positionValue * stopLossPercent;
          return -loss - (positionValue * fee);
        }
        if (priceChange >= takeProfitPercent) {
          final profit = positionValue * takeProfitPercent;
          return profit - (positionValue * fee);
        }
      } else if (action == 'SELL') {
        if (priceChange >= stopLossPercent) {
          final loss = positionValue * stopLossPercent;
          return -loss - (positionValue * fee);
        }
        if (priceChange <= -takeProfitPercent) {
          final profit = positionValue * takeProfitPercent;
          return profit - (positionValue * fee);
        }
      }
    }
    final last = futureCandles.last.close;
    final finalChange = (last - entryPrice) / (entryPrice == 0 ? 1 : entryPrice);
    final dir = (action == 'BUY') ? 1.0 : -1.0;
    return positionValue * (dir * finalChange) - (positionValue * fee);
  }
}


