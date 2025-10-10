import 'dart:convert';

/// BacktestResult - immutable snapshot of a backtest run
class BacktestResult {
  final DateTime start;
  final DateTime end;
  final String symbol;
  final String interval;

  // Equity curve (timestamp -> equity)
  final List<DateTime> times;
  final List<double> equity;

  // Optional trades log
  final List<TradeRecord> trades;

  // Metrics
  final double initialCapital;
  final double finalCapital;
  final double totalReturn; // fraction, e.g., 0.12 = 12%
  final int numTrades;
  final int winningTrades;
  final int losingTrades;
  final double avgWin;
  final double avgLoss;
  final double maxDrawdown; // fraction
  final double sharpe; // daily Sharpe 
  final double feesPaid;

  const BacktestResult({
    required this.start,
    required this.end,
    required this.symbol,
    required this.interval,
    required this.times,
    required this.equity,
    required this.initialCapital,
    required this.finalCapital,
    required this.totalReturn,
    required this.numTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.avgWin,
    required this.avgLoss,
    required this.maxDrawdown,
    required this.sharpe,
    required this.feesPaid,
    this.trades = const [],
  });

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'symbol': symbol,
        'interval': interval,
        'initialCapital': initialCapital,
        'finalCapital': finalCapital,
        'totalReturn': totalReturn,
        'numTrades': numTrades,
        'winningTrades': winningTrades,
        'losingTrades': losingTrades,
        'avgWin': avgWin,
        'avgLoss': avgLoss,
        'maxDrawdown': maxDrawdown,
        'sharpe': sharpe,
        'feesPaid': feesPaid,
        'trades': trades.map((t) => t.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}

class TradeRecord {
  final DateTime time;
  final String action; // BUY/SELL
  final double price;
  final double qty;
  final double fee;
  final double pnl;

  const TradeRecord({
    required this.time,
    required this.action,
    required this.price,
    required this.qty,
    required this.fee,
    required this.pnl,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'action': action,
        'price': price,
        'qty': qty,
        'fee': fee,
        'pnl': pnl,
      };
}


