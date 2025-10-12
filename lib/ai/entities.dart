import 'dart:math';
import 'ai_config.dart';

/// Candle (OHLCV) - unitatea de bază pentru date de piață
class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Log return: ln(close_t / close_prev)
  double logReturn(Candle prev) => log(close / prev.close);

  /// True range pentru ATR
  double trueRange(Candle? prev) {
    if (prev == null) return high - low;
    return max(
      high - low,
      max((high - prev.close).abs(), (low - prev.close).abs()),
    );
  }

  factory Candle.fromList(List<dynamic> data) {
    // Format Binance: [timestamp, open, high, low, close, volume, ...]
    return Candle(
      time: DateTime.fromMillisecondsSinceEpoch(data[0] as int),
      open: _toDouble(data[1]),
      high: _toDouble(data[2]),
      low: _toDouble(data[3]),
      close: _toDouble(data[4]),
      volume: _toDouble(data[5]),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.parse(v);
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': volume,
      };
}

/// Prediction - output complet al ML pipeline
class Prediction {
  final String symbol;
  final DateTime asOf;
  final double pBuy; // Probability BUY (0-1)
  final double pHold; // Probability HOLD (0-1)
  final double pSell; // Probability SELL (0-1)
  final double expReturn; // Expected return (fracție: 0.012 = +1.2%)
  final double annVol; // Volatilitate anualizată (0.65 = 65%)
  final double relVolume; // Volum relativ vs SMA20
  final String? reason; // Optional machine reason (e.g., 'model_missing')

  const Prediction({
    required this.symbol,
    required this.asOf,
    required this.pBuy,
    required this.pHold,
    required this.pSell,
    required this.expReturn,
    required this.annVol,
    required this.relVolume,
    this.reason,
  });

  /// Action determinat din probabilități (multiclass softmax)
  String get action {
    if (pBuy >= pSell && pBuy >= pHold) return 'BUY';
    if (pSell > pBuy && pSell >= pHold) return 'SELL';
    return 'HOLD';
  }

  /// Confidence score calibrat cu volatilitate
  double confidence({double volCap = 0.85}) {
    final maxProb = [pBuy, pHold, pSell].reduce((a, b) => a > b ? a : b);
    final volPenalty = (1.0 - min(1.0, annVol / volCap)).clamp(0.0, 1.0);
    final volumeBoost = min(1.2, max(0.8, relVolume)); // Boost dacă volum mare
    return (maxProb * volPenalty * (volumeBoost / 1.2)).clamp(0.0, 1.0);
  }

  /// Target price bazat pe expected return
  double targetPrice(double lastClose) => lastClose * (1.0 + expReturn);

  /// Conversie la percentage pentru UI
  double get confidencePercent => confidence() * 100.0;
  double get expReturnPercent => expReturn * 100.0;
  double get annVolPercent => annVol * 100.0;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'asOf': asOf.toIso8601String(),
        'pBuy': pBuy,
        'pHold': pHold,
        'pSell': pSell,
        'expReturn': expReturn,
        'annVol': annVol,
        'relVolume': relVolume,
        'action': action,
        'confidence': confidence(),
        if (reason != null) 'reason': reason,
      };
}

/// Strategy Settings - configurare thresholds și parametri
class StrategySettings {
  final double upThresh; // Threshold pentru BUY (ex: 0.003 = +0.3%)
  final double downThresh; // Threshold pentru SELL (ex: -0.003 = -0.3%)
  final double confThresh; // Confidence minimum (ex: 0.6 = 60%)
  final double volCap; // Volatility cap anualizat (ex: 0.85 = 85%)
  final double fee; // Comision per trade (0.001 = 0.1%)
  final double slippage; // Slippage estimat (0.0005 = 0.05%)
  final String timeframe; // ex: '5m'
  final int window; // e.g., 64
  final int history; // e.g., 100
  final int seed; // global seed

  const StrategySettings({
    this.upThresh = 0.01,
    this.downThresh = -0.01,
    this.confThresh = 0.40,
    this.volCap = 0.85,
    this.fee = 0.001,
    this.slippage = 0.0005,
    this.timeframe = AiConfig.timeframe,
    this.window = AiConfig.window,
    this.history = AiConfig.history,
    this.seed = AiConfig.seed,
  });

  StrategySettings copyWith({
    double? upThresh,
    double? downThresh,
    double? confThresh,
    double? volCap,
    double? fee,
    double? slippage,
    String? timeframe,
    int? window,
    int? history,
    int? seed,
  }) {
    return StrategySettings(
      upThresh: upThresh ?? this.upThresh,
      downThresh: downThresh ?? this.downThresh,
      confThresh: confThresh ?? this.confThresh,
      volCap: volCap ?? this.volCap,
      fee: fee ?? this.fee,
      slippage: slippage ?? this.slippage,
      timeframe: timeframe ?? this.timeframe,
      window: window ?? this.window,
      history: history ?? this.history,
      seed: seed ?? this.seed,
    );
  }

  Map<String, dynamic> toJson() => {
        'upThresh': upThresh,
        'downThresh': downThresh,
        'confThresh': confThresh,
        'volCap': volCap,
        'fee': fee,
        'slippage': slippage,
        'timeframe': timeframe,
        'window': window,
        'history': history,
        'seed': seed,
      };
}

/// Indicators - agregare pentru o anumită fereastră
class Indicators {
  final double rsi14;
  final double ema12;
  final double ema26;
  final double macd;
  final double atr14;
  final double obv;
  final double ewmaVol;
  final double relVolume;

  const Indicators({
    required this.rsi14,
    required this.ema12,
    required this.ema26,
    required this.macd,
    required this.atr14,
    required this.obv,
    required this.ewmaVol,
    required this.relVolume,
  });

  Map<String, dynamic> toJson() => {
        'rsi14': rsi14,
        'ema12': ema12,
        'ema26': ema26,
        'macd': macd,
        'atr14': atr14,
        'obv': obv,
        'ewmaVol': ewmaVol,
        'relVolume': relVolume,
      };
}
