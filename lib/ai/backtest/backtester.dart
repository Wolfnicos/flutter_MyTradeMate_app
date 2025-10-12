import '../entities.dart';
import '../signal_engine.dart';
import 'metrics.dart';

/// BacktestResult - rezultat complet al unui backtest
class BacktestResult {
  final List<double> equity; // Equity curve (valoare portofoliu în timp)
  final List<String> actions; // Lista acțiunilor luate
  final List<DateTime> timestamps; // Timestamps pentru fiecare punct
  final Metrics metrics; // Performance metrics
  final double initialCapital;
  final double finalCapital;

  BacktestResult({
    required this.equity,
    required this.actions,
    required this.timestamps,
    required this.metrics,
    required this.initialCapital,
    required this.finalCapital,
  });

  Map<String, dynamic> toJson() => {
        'equity': equity,
        'actions': actions,
        'timestamps': timestamps.map((t) => t.toIso8601String()).toList(),
        'metrics': metrics.toJson(),
        'initialCapital': initialCapital,
        'finalCapital': finalCapital,
      };
}

/// Trade - reprezentare a unui trade individual
class Trade {
  final DateTime entryTime;
  final DateTime? exitTime;
  final double entryPrice;
  final double? exitPrice;
  final double quantity;
  final String side; // 'BUY' sau 'SELL'

  Trade({
    required this.entryTime,
    this.exitTime,
    required this.entryPrice,
    this.exitPrice,
    required this.quantity,
    required this.side,
  });

  double? get pnl {
    if (exitPrice == null) return null;
    final diff =
        side == 'BUY' ? (exitPrice! - entryPrice) : (entryPrice - exitPrice!);
    return diff * quantity;
  }

  double? get pnlPercent {
    if (exitPrice == null) return null;
    return side == 'BUY'
        ? (exitPrice! / entryPrice) - 1.0
        : 1.0 - (exitPrice! / entryPrice);
  }
}

/// Backtester - simulează strategia pe date istorice
class Backtester {
  final SignalEngine engine;
  final StrategySettings settings;

  Backtester(this.engine, this.settings);

  /// Run backtest pe date OHLCV
  /// - symbol: ex 'BTCUSDT'
  /// - data: listă de candles istorice
  /// - initial: capital inițial (ex: 10000)
  /// - position: poziție fracțională per trade (0.1 = 10%)
  /// - windowSize: câte candles pentru predicție (default: 50)
  Future<BacktestResult> run(
    String symbol,
    List<Candle> data, {
    double initial = 10000.0,
    double position = 0.1,
    int windowSize = 50,
  }) async {
    double cash = initial;
    double qty = 0.0;
    final equityCurve = <double>[];
    final actionsList = <String>[];
    final timestamps = <DateTime>[];
    final trades = <Trade>[];
    Trade? currentTrade;

    int buyCount = 0;
    int sellCount = 0;

    for (int i = windowSize; i < data.length; i++) {
      final window = data.sublist(i - windowSize, i);
      final pred = await engine.predict(symbol, window);
      if (pred == null) {
        // Not enough data or model unavailable at this step – skip safely.
        continue;
      }
      final action = engine.decide(pred);
      final currentCandle = data[i];
      final price = currentCandle.close;

      // Apply slippage
      final buyPrice = price * (1 + settings.slippage);
      final sellPrice = price * (1 - settings.slippage);

      // Execute BUY
      if (action == 'BUY' && cash > 0 && qty == 0) {
        final spend = cash * position;
        final feeAmount = spend * settings.fee;
        final netSpend = spend - feeAmount;
        qty = netSpend / buyPrice;
        cash -= spend;
        buyCount++;

        currentTrade = Trade(
          entryTime: currentCandle.time,
          entryPrice: buyPrice,
          quantity: qty,
          side: 'BUY',
        );
      }
      // Execute SELL (exit long position)
      else if (action == 'SELL' && qty > 0) {
        final proceeds = qty * sellPrice;
        final feeAmount = proceeds * settings.fee;
        final netProceeds = proceeds - feeAmount;
        cash += netProceeds;
        sellCount++;

        if (currentTrade != null) {
          trades.add(Trade(
            entryTime: currentTrade.entryTime,
            exitTime: currentCandle.time,
            entryPrice: currentTrade.entryPrice,
            exitPrice: sellPrice,
            quantity: qty,
            side: currentTrade.side,
          ));
        }

        qty = 0;
        currentTrade = null;
      }

      // Mark to market
      final portfolioValue = cash + (qty * price);
      equityCurve.add(portfolioValue);
      actionsList.add(action);
      timestamps.add(currentCandle.time);
    }

    // Close any open position at end
    if (qty > 0) {
      final finalPrice = data.last.close;
      cash += qty * finalPrice;
      qty = 0;
    }

    final finalCapital = equityCurve.isEmpty ? initial : equityCurve.last;

    // Calculate metrics
    final completedTrades = trades.length;
    final winningTrades = trades.where((t) => (t.pnl ?? 0) > 0).length;
    final losingTrades = trades.where((t) => (t.pnl ?? 0) < 0).length;

    final metrics = Metrics.fromEquity(
      equityCurve,
      trades: completedTrades,
      wins: winningTrades,
      losses: losingTrades,
    );

    return BacktestResult(
      equity: equityCurve,
      actions: actionsList,
      timestamps: timestamps,
      metrics: metrics,
      initialCapital: initial,
      finalCapital: finalCapital,
    );
  }
}
