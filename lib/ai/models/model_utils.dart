import 'dart:math';
import '../entities.dart';
import 'stats.dart';

class ModelUtils {
  /// Extract features from candles for model input
  /// Returns: List of [windowSize] timesteps, each with [numFeatures] features
  static List<List<double>> featuresFromCandles(
    List<Candle> candles,
    int windowSize,
    int numFeatures,
  ) {
    if (candles.length < windowSize) {
      throw ArgumentError(
        'Need at least $windowSize candles, got ${candles.length}',
      );
    }

    // Take the last windowSize candles
    final window = candles.sublist(candles.length - windowSize);
    
    final features = <List<double>>[];
    
    final useExtended = numFeatures >= 25;
    for (int i = 0; i < windowSize; i++) {
      var timestepFeatures = useExtended
          ? _extractTimestepFeaturesExtended(window, i)
          : _extractTimestepFeatures(window, i);

      // Be tolerant to model-declared feature size; pad/trim to fit
      if (timestepFeatures.length != numFeatures) {
        timestepFeatures = _coerceFeaturesLength(timestepFeatures, numFeatures);
      }
      
      features.add(timestepFeatures);
    }

    return features;
  }

  /// Ensure features list matches the expected length by padding with zeros
  /// or trimming extra values.
  static List<double> _coerceFeaturesLength(List<double> feats, int targetLen) {
    if (feats.length == targetLen) return feats;
    if (feats.length < targetLen) {
      return [...feats, ...List.filled(targetLen - feats.length, 0.0)];
    }
    return feats.sublist(0, targetLen);
  }

  /// Normalize 2D features using training statistics
  static List<double> normalize2D(List<List<double>> features) {
    // Coerce each timestep to the expected stats feature length before normalizing
    final expectedLen = NormalizationStats.means.length;
    final adjusted = <List<double>>[];
    for (var t in features) {
      if (t.length != expectedLen) {
        t = _coerceFeaturesLength(t, expectedLen);
      }
      adjusted.add(t);
    }
    return NormalizationStats.normalize2D(adjusted);
  }

  /// Extract features for a single timestep
  static List<double> _extractTimestepFeatures(
    List<Candle> window,
    int idx,
  ) {
    final current = window[idx];
    final features = <double>[];

    // Feature 0-2: Returns (ret1, ret5, ret15)
    features.add(_getReturn(window, idx, 1));
    features.add(_getReturn(window, idx, 5));
    features.add(_getReturn(window, idx, 15));

    // Feature 3: HL range (normalized by close)
    final hlRange = (current.high - current.low) / current.close;
    features.add(hlRange);

    // Feature 4: CO ratio
    final coRatio = current.close / current.open;
    features.add(coRatio);

    // Feature 5-6: EMAs (normalized by close for stability)
    final ema12 = _calculateEMA(window.sublist(0, idx + 1), 12);
    final ema26 = _calculateEMA(window.sublist(0, idx + 1), 26);
    features.add(ema12 / current.close); // Relative EMA
    features.add(ema26 / current.close);

    // Feature 7: MACD (normalized by close)
    final macd = (ema12 - ema26) / current.close;
    features.add(macd);

    // Feature 8: RSI (already bounded [0, 100])
    final rsi = _calculateRSI(window.sublist(0, idx + 1), 14);
    features.add(rsi);

    // Feature 9: ATR (normalized by close)
    final atr = _calculateATR(window.sublist(0, idx + 1), 14);
    features.add(atr / current.close);

    // Feature 10: OBV normalized
    final obvNorm = _calculateOBVNorm(window.sublist(0, idx + 1));
    features.add(obvNorm);

    // Feature 11-12: Volume metrics
    final avgVol = window.map((c) => c.volume).reduce((a, b) => a + b) / window.length;
    final volumeRel = current.volume / (avgVol + 1e-10); // Avoid division by zero
    final volumeZ = (current.volume - avgVol) / (avgVol + 1e-10);
    features.add(volumeRel);
    features.add(volumeZ);

    // Feature 13-14: Rolling statistics (normalized by close)
    final closes = window.sublist(0, idx + 1).map((c) => c.close).toList();
    final rollingStd = _std(closes) / current.close;
    final rollingMean = _mean(closes) / current.close;
    features.add(rollingStd);
    features.add(rollingMean);

    return features;
  }

  /// Extended features set (adds 10 extra signals on top of the base 15)
  /// Total = 25 features
  static List<double> _extractTimestepFeaturesExtended(
    List<Candle> window,
    int idx,
  ) {
    final base = _extractTimestepFeatures(window, idx);
 
    // Helper arrays for ranged computations
    final highsAll = window.map((c) => c.high).toList();
    final lowsAll = window.map((c) => c.low).toList();
    final closesAll = window.map((c) => c.close).toList();
 
    // 1) Bollinger Bands (period 20): upper, lower, %B
    final bb = _bollinger(closesAll, idx, period: 20, mult: 2.0);
    base.addAll([bb.upperRatio, bb.lowerRatio, bb.percentB]);

    // 2) Stochastic Oscillator %K, %D (period 14, D=3 SMA)
    final sto = _stochastic(highsAll, lowsAll, closesAll, idx, kPeriod: 14, dPeriod: 3);
    base.addAll([sto.k, sto.d]);

    // 3) Williams %R (period 14) scaled to [-1, 0]
    final wr = _williamsR(highsAll, lowsAll, closesAll, idx, period: 14);
    base.add(wr);

    // 4) ADX 14 (approximate DI+/DI- and smooth)
    final adx = _adx(window, idx, period: 14);
    base.add(adx);

    // 5) Ichimoku: tenkan/kijun ratio, spanA-spanB distance/close, cloud position sign
    final ichi = _ichimoku(window, idx);
    base.addAll([ichi.tenkanKijun, ichi.spanDist, ichi.cloudPos]);

    // 6) Volume Profile proxy over last 20: vwap/close, vahDist, valDist
    final vp = _volumeProfileProxy(window, idx, lookback: 20);
    base.addAll([vp.vwapRatio, vp.vahDist, vp.valDist]);

    // 7) Order flow proxy: body/trueRange * volume normalized [-1..1]
    final of = _orderFlowProxy(window, idx, lookback: 20);
    base.add(of);

    // 8) Multi-timeframe returns: 1h (12×5m), 4h (48×5m)
    base.add(_multiTfReturn(closesAll, idx, periods: 12));
    base.add(_multiTfReturn(closesAll, idx, periods: 48));

    // 9) Market regime (trend=1 / range=0) based pe ADX > 25
    base.add(adx > 25 ? 1.0 : 0.0);

    // 10) BTC dominance correlation placeholder (not available) => 0.0
    base.add(0.0);

    return base;
  }

  /// Calculate return over N periods
  static double _getReturn(List<Candle> window, int idx, int periods) {
    if (idx < periods) {
      return 0.0; // Not enough history
    }
    
    final current = window[idx].close;
    final past = window[idx - periods].close;
    
    if (past == 0) return 0.0;
    
    return (current - past) / past;
  }

  /// Calculate Exponential Moving Average
  static double _calculateEMA(List<Candle> data, int period) {
    if (data.isEmpty) return 0.0;
    if (data.length < period) return data.last.close;

    final alpha = 2.0 / (period + 1);
    double ema = data[0].close;

    for (int i = 1; i < data.length; i++) {
      ema = data[i].close * alpha + ema * (1 - alpha);
    }

    return ema;
  }

  /// Calculate Relative Strength Index
  static double _calculateRSI(List<Candle> data, int period) {
    if (data.length < period + 1) return 50.0; // Neutral RSI

    double gains = 0;
    double losses = 0;

    for (int i = data.length - period; i < data.length; i++) {
      if (i == 0) continue;
      
      final change = data[i].close - data[i - 1].close;
      if (change > 0) {
        gains += change;
        } else {
        losses += -change;
      }
    }

    if (losses == 0) return 100.0;
    
    final avgGain = gains / period;
    final avgLoss = losses / period;
    final rs = avgGain / avgLoss;
    
    return 100 - (100 / (1 + rs));
  }

  /// Calculate Average True Range
  static double _calculateATR(List<Candle> data, int period) {
    if (data.length < 2) return data.last.high - data.last.low;
    if (data.length < period + 1) {
      return data.last.high - data.last.low;
    }

    final trs = <double>[];
    
    for (int i = 1; i < data.length; i++) {
      final high = data[i].high;
      final low = data[i].low;
      final prevClose = data[i - 1].close;

      final tr = [
        high - low,
        (high - prevClose).abs(),
        (low - prevClose).abs(),
      ].reduce((a, b) => a > b ? a : b);

      trs.add(tr);
    }

    final recentTRs = trs.length > period 
        ? trs.sublist(trs.length - period)
        : trs;
    
    return recentTRs.reduce((a, b) => a + b) / recentTRs.length;
  }

  /// Calculate normalized On-Balance Volume
  static double _calculateOBVNorm(List<Candle> data) {
    if (data.length < 2) return 0.5; // Neutral

    double obv = 0;
    
    for (int i = 1; i < data.length; i++) {
      if (data[i].close > data[i - 1].close) {
        obv += data[i].volume;
      } else if (data[i].close < data[i - 1].close) {
        obv -= data[i].volume;
      }
      // If equal, OBV doesn't change
    }

    // Normalize to [0, 1] range
    // Max possible OBV would be sum of all volumes
    final maxObv = data.map((c) => c.volume).reduce((a, b) => a + b);
    
    if (maxObv == 0) return 0.5;
    
    // Map from [-maxObv, +maxObv] to [0, 1]
    return (obv / maxObv + 1) / 2;
  }

  /// Calculate mean of a list
  static double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation
  static double _std(List<double> values) {
    if (values.isEmpty) return 0.0;
    if (values.length == 1) return 0.0;
    
    final mean = _mean(values);
    final variance = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return sqrt(variance);
  }

  // ---------------- Extended indicators helpers -----------------
  static ({double upperRatio, double lowerRatio, double percentB}) _bollinger(
    List<double> closes,
    int idx, {
    int period = 20,
    double mult = 2.0,
  }) {
    final end = idx + 1;
    final start = (end - period) < 0 ? 0 : (end - period);
    final slice = closes.sublist(start, end);
    final m = _mean(slice);
    final s = _std(slice);
    final upper = m + mult * s;
    final lower = m - mult * s;
    final close = closes[idx];
    final denom = (upper - lower).abs() < 1e-12 ? 1e-12 : (upper - lower);
    final pB = (close - lower) / denom;
    return (
      upperRatio: close / (upper == 0 ? 1.0 : upper),
      lowerRatio: close / (lower == 0 ? 1.0 : lower),
      percentB: pB.clamp(-3.0, 3.0),
    );
  }

  static ({double k, double d}) _stochastic(
    List<double> highs,
    List<double> lows,
    List<double> closes,
    int idx, {
    int kPeriod = 14,
    int dPeriod = 3,
  }) {
    final end = idx + 1;
    final start = (end - kPeriod) < 0 ? 0 : (end - kPeriod);
    final h = highs.sublist(start, end).reduce((a, b) => a > b ? a : b);
    final l = lows.sublist(start, end).reduce((a, b) => a < b ? a : b);
    final c = closes[idx];
    final denom = (h - l).abs() < 1e-12 ? 1e-12 : (h - l);
    final k = ((c - l) / denom) * 100.0;
    // D as SMA of last dPeriod of K
    final ks = <double>[];
    for (int j = 0; j < dPeriod; j++) {
      final ii = idx - j;
      if (ii < 0) break;
      final ee = ii + 1;
      final ss = (ee - kPeriod) < 0 ? 0 : (ee - kPeriod);
      final hh = highs.sublist(ss, ee).reduce((a, b) => a > b ? a : b);
      final ll = lows.sublist(ss, ee).reduce((a, b) => a < b ? a : b);
      final cc = closes[ii];
      final den = (hh - ll).abs() < 1e-12 ? 1e-12 : (hh - ll);
      ks.add(((cc - ll) / den) * 100.0);
    }
    final d = ks.isEmpty ? k : _mean(ks);
    return (k: k.clamp(0.0, 100.0), d: d.clamp(0.0, 100.0));
  }

  static double _williamsR(
    List<double> highs,
    List<double> lows,
    List<double> closes,
    int idx, {
    int period = 14,
  }) {
    final end = idx + 1;
    final start = (end - period) < 0 ? 0 : (end - period);
    final h = highs.sublist(start, end).reduce((a, b) => a > b ? a : b);
    final l = lows.sublist(start, end).reduce((a, b) => a < b ? a : b);
    final c = closes[idx];
    final denom = (h - l).abs() < 1e-12 ? 1e-12 : (h - l);
    final wr = -100.0 * (h - c) / denom; // [-100..0]
    return (wr / 100.0).clamp(-1.0, 0.0); // scale to [-1..0]
  }

  static double _adx(List<Candle> data, int idx, {int period = 14}) {
    // Simplified ADX over up to [idx-period*2 .. idx]
    if (idx < 2) return 0.0;
    final end = idx + 1;
    final start = (end - (period + 1)) < 1 ? 1 : (end - (period + 1));
    double trSum = 0.0, plusDmSum = 0.0, minusDmSum = 0.0;
    for (int i = start; i < end; i++) {
      final high = data[i].high;
      final low = data[i].low;
      final prevClose = data[i - 1].close;
      final prevHigh = data[i - 1].high;
      final prevLow = data[i - 1].low;
      final tr = [
        high - low,
        (high - prevClose).abs(),
        (low - prevClose).abs(),
      ].reduce((a, b) => a > b ? a : b);
      final upMove = high - prevHigh;
      final downMove = prevLow - low;
      final plusDm = (upMove > downMove && upMove > 0) ? upMove : 0.0;
      final minusDm = (downMove > upMove && downMove > 0) ? downMove : 0.0;
      trSum += tr;
      plusDmSum += plusDm;
      minusDmSum += minusDm;
    }
    if (trSum == 0) return 0.0;
    final plusDi = 100.0 * (plusDmSum / trSum);
    final minusDi = 100.0 * (minusDmSum / trSum);
    final den = (plusDi + minusDi).abs() < 1e-12 ? 1e-12 : (plusDi + minusDi);
    final dx = 100.0 * ((plusDi - minusDi).abs() / den);
    return dx; // treat as ADX proxy at current step
  }

  static ({double tenkanKijun, double spanDist, double cloudPos}) _ichimoku(
    List<Candle> data,
    int idx,
  ) {
    double _mid(int period) {
      final end = idx + 1;
      final start = (end - period) < 0 ? 0 : (end - period);
      final highs = data.sublist(start, end).map((c) => c.high);
      final lows = data.sublist(start, end).map((c) => c.low);
      final h = highs.reduce((a, b) => a > b ? a : b);
      final l = lows.reduce((a, b) => a < b ? a : b);
      return (h + l) / 2.0;
    }

    final tenkan = _mid(9);
    final kijun = _mid(26);
    final spanA = (tenkan + kijun) / 2.0;
    final spanB = _mid(52);
    final close = data[idx].close;
    final spanMax = spanA > spanB ? spanA : spanB;
    final spanMin = spanA > spanB ? spanB : spanA;
    final tenkanKijun = kijun == 0 ? 1.0 : (tenkan / kijun);
    final spanDist = (spanMax - spanMin) / (close == 0 ? 1.0 : close);
    final cloudPos = close >= spanMax ? 1.0 : (close <= spanMin ? -1.0 : 0.0);
    return (tenkanKijun: tenkanKijun, spanDist: spanDist, cloudPos: cloudPos);
  }

  static ({double vwapRatio, double vahDist, double valDist}) _volumeProfileProxy(
    List<Candle> data,
    int idx, {
    int lookback = 20,
  }) {
    final end = idx + 1;
    final start = (end - lookback) < 0 ? 0 : (end - lookback);
    double volSum = 0.0, pvSum = 0.0;
    final prices = <double>[];
    for (int i = start; i < end; i++) {
      final c = data[i];
      volSum += c.volume;
      pvSum += c.close * c.volume;
      prices.add(c.close);
    }
    final vwap = volSum == 0 ? data[idx].close : pvSum / volSum;
    final mean = _mean(prices);
    final sd = _std(prices);
    final vah = mean + sd; // proxy
    final val = mean - sd; // proxy
    final close = data[idx].close;
    final vwapRatio = close / (vwap == 0 ? 1.0 : vwap);
    final vahDist = (close - vah) / (close == 0 ? 1.0 : close);
    final valDist = (close - val) / (close == 0 ? 1.0 : close);
    return (vwapRatio: vwapRatio, vahDist: vahDist, valDist: valDist);
  }

  static double _orderFlowProxy(
    List<Candle> data,
    int idx, {
    int lookback = 20,
  }) {
    final c = data[idx];
    final tr = (c.high - c.low).abs() < 1e-12 ? 1e-12 : (c.high - c.low);
    final body = (c.close - c.open) / tr; // [-inf..inf] but bounded by clamp below
    final avgVol = data
            .sublist((idx + 1 - lookback) < 0 ? 0 : (idx + 1 - lookback), idx + 1)
            .map((e) => e.volume)
            .fold<double>(0.0, (a, b) => a + b) /
        (lookback < 1 ? 1 : (idx + 1 < lookback ? (idx + 1) : lookback));
    final relVol = avgVol == 0 ? 0.0 : (c.volume / avgVol);
    return (body * relVol).clamp(-3.0, 3.0);
  }

  static double _multiTfReturn(List<double> closes, int idx, {required int periods}) {
    if (idx < periods) return 0.0;
    final past = closes[idx - periods];
    final cur = closes[idx];
    if (past == 0) return 0.0;
    return (cur - past) / past;
  }

  // ========================================================================
  // BACKWARDS COMPATIBILITY for ReturnModel and VolatilityModel
  // ========================================================================

  /// Build input tensor matching the model-declared shape, handling swapped axes.
  static dynamic buildInputTensor(List<Candle> window, List<int> inShape) {
    if (inShape.length < 3) {
      throw ArgumentError('Unsupported input shape: $inShape');
    }

    // Model may declare either [1, 64, 15] (time, features) or [1, 15, 64] (features, time)
    final dimA = inShape[1];
    final dimB = inShape[2];

    // Determine intended time/feature dims (we expect 64x15)
    final timeDim = (dimA == 64 || dimB == 64) ? 64 : dimA; // fallback to dimA if unknown
    final featDim = (dimA == 15 || dimB == 15) ? 15 : dimB; // fallback to dimB if unknown

    // Extract canonical [timeDim, featDim] features and normalize to stats length
    final featsTF = featuresFromCandles(window, timeDim, featDim);
    final flatCanonical = normalize2D(featsTF); // produces timeDim * 15 flat

    if (inShape.length == 3) {
      // If shape matches [1, time, feat], reshape directly
      if (dimA == timeDim && dimB == featDim) {
        return _reshapeTo3D(flatCanonical, [1, timeDim, featDim]);
      }
      // If shape is [1, feat, time], first reshape [1,time,feat] then transpose to [1,feat,time]
      if (dimA == featDim && dimB == timeDim) {
        final asTimeFeat = _reshapeTo3D(flatCanonical, [1, timeDim, featDim]);
        return _transposeTimeFeat3D(asTimeFeat); // [1, feat, time]
      }
    } else if (inShape.length == 4) {
      // Channels-last variant: either [1,time,feat,1] or [1,feat,time,1]
      final channels = inShape[3];
      if (channels != 1) {
        // Only support single channel
        throw ArgumentError('Unsupported channels in input shape: $inShape');
      }
      if (dimA == timeDim && dimB == featDim) {
        final t3 = _reshapeTo3D(flatCanonical, [1, timeDim, featDim]);
        return _expandChannels(t3, channels);
      }
      if (dimA == featDim && dimB == timeDim) {
        final t3 = _reshapeTo3D(flatCanonical, [1, timeDim, featDim]);
        final ft3 = _transposeTimeFeat3D(t3);
        return _expandChannels(ft3, channels);
      }
    }

    // Fallback: shape as declared (will pad zeros if needed)
    return _reshapeTo3D(flatCanonical, [1, dimA, dimB]);
  }

  /// Create empty output tensor of given shape
  static dynamic emptyOutput(List<int> outShape) {
    if (outShape.length == 1) {
      return List.filled(outShape[0], 0.0);
    } else if (outShape.length == 2) {
      return List.generate(
        outShape[0],
        (_) => List.filled(outShape[1], 0.0),
      );
    } else if (outShape.length == 3) {
      return List.generate(
        outShape[0],
        (_) => List.generate(
          outShape[1],
          (_) => List.filled(outShape[2], 0.0),
        ),
      );
    }
    
    throw ArgumentError('Unsupported output shape: $outShape');
  }

  /// Extract scalar value from output tensor
  static double extractScalar(dynamic output, List<int> outShape) {
    if (outShape.length == 1) {
      // [1] -> output[0]
      return (output as List<double>)[0];
    } else if (outShape.length == 2) {
      // [1, 1] -> output[0][0]
      return (output as List<List<double>>)[0][0];
    } else if (outShape.length == 3) {
      // [1, 1, 1] -> output[0][0][0]
      return (output as List<List<List<double>>>)[0][0][0];
    }
    
    throw ArgumentError('Cannot extract scalar from shape: $outShape');
  }

  static List<List<List<double>>> _reshapeTo3D(
    List<double> flat,
    List<int> shape,
  ) {
    final result = <List<List<double>>>[];
    int idx = 0;

    for (int b = 0; b < shape[0]; b++) {
      final batch = <List<double>>[];
      for (int t = 0; t < shape[1]; t++) {
        final timestep = <double>[];
        for (int f = 0; f < shape[2]; f++) {
          timestep.add(idx < flat.length ? flat[idx++] : 0.0);
        }
        batch.add(timestep);
      }
      result.add(batch);
    }

    return result;
  }

  static List<List<List<List<double>>>> _reshapeTo4D(
    List<double> flat,
    List<int> shape,
  ) {
    final result = <List<List<List<double>>>>[];
    int idx = 0;

    for (int b = 0; b < shape[0]; b++) {
      final batch = <List<List<double>>>[];
      for (int t = 0; t < shape[1]; t++) {
        final timestep = <List<double>>[];
        for (int f = 0; f < shape[2]; f++) {
          final channel = <double>[];
          for (int c = 0; c < shape[3]; c++) {
            channel.add(idx < flat.length ? flat[idx++] : 0.0);
          }
          timestep.add(channel);
        }
        batch.add(timestep);
      }
      result.add(batch);
    }

    return result;
  }

  /// Transpose [1, time, feat] -> [1, feat, time]
  static List<List<List<double>>> _transposeTimeFeat3D(
    List<List<List<double>>> x,
  ) {
    // x[0] shape: [time][feat]
    final time = x[0].length;
    final feat = x[0][0].length;
    final out = <List<List<double>>>[List.generate(feat, (_) => List.filled(time, 0.0))];
    for (int t = 0; t < time; t++) {
      for (int f = 0; f < feat; f++) {
        out[0][f][t] = x[0][t][f];
      }
    }
    return out;
  }

  /// Expand [1, A, B] -> [1, A, B, C] with identical channel copies (C=1 used)
  static List<List<List<List<double>>>> _expandChannels(
    List<List<List<double>>> x,
    int channels,
  ) {
    final a = x[0].length;
    final b = x[0][0].length;
    final out = <List<List<List<double>>>>[];
    final batch = <List<List<double>>>[];
    for (int i = 0; i < a; i++) {
      final row = <List<double>>[];
      for (int j = 0; j < b; j++) {
        final ch = List<double>.filled(channels, 0.0);
        ch[0] = x[0][i][j];
        row.add(ch);
      }
      batch.add(row);
    }
    out.add(batch);
    return out;
  }
}

