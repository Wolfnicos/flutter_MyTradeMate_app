import 'package:flutter/foundation.dart' show visibleForTesting;

class ExchangeRules {
  final int priceScale;
  final int qtyScale;
  final double tickSize;
  final double stepSize;
  final double minNotional;

  ExchangeRules({
    required this.priceScale,
    required this.qtyScale,
    required this.tickSize,
    required this.stepSize,
    required this.minNotional,
  });

  factory ExchangeRules.fromExchangeInfo(
      Map<String, dynamic> info, String symbol) {
    final sym =
        (info['symbols'] as List).firstWhere((s) => s['symbol'] == symbol);
    int priceScale = 8, qtyScale = 8;
    double tickSize = 0.00000001, stepSize = 0.00000001, minNotional = 0.0;

    for (final f in sym['filters']) {
      switch (f['filterType']) {
        case 'PRICE_FILTER':
          tickSize = double.parse(f['tickSize']);
          priceScale = _scaleFromStep(tickSize);
          break;
        case 'LOT_SIZE':
          stepSize = double.parse(f['stepSize']);
          qtyScale = _scaleFromStep(stepSize);
          break;
        case 'MIN_NOTIONAL':
          minNotional = double.parse(f['minNotional']);
          break;
      }
    }
    return ExchangeRules(
      priceScale: priceScale,
      qtyScale: qtyScale,
      tickSize: tickSize,
      stepSize: stepSize,
      minNotional: minNotional,
    );
  }

  static int _scaleFromStep(double v) {
    // Compute number of decimal places by multiplying until integer
    int scale = 0;
    double x = v.abs();
    // Guard zero
    if (x == 0) return 0;
    while ((x - x.roundToDouble()).abs() > 1e-12 && scale < 12) {
      x *= 10.0;
      scale++;
    }
    return scale;
  }

  double roundPrice(double p) {
    final k = (p / tickSize).floorToDouble();
    final v = k * tickSize;
    return double.parse(v.toStringAsFixed(priceScale));
  }

  double roundQty(double q) {
    final k = (q / stepSize).floorToDouble();
    final v = k * stepSize;
    return double.parse(v.toStringAsFixed(qtyScale));
  }

  String? validateNotional({required double price, required double qty}) {
    final notional = price * qty;
    if (notional + 1e-12 < minNotional) {
      return 'Amount too small; min notional is ${minNotional.toStringAsFixed(2)}';
    }
    if (qty <= 0) return 'Quantity too small';
    return null;
  }
}

@visibleForTesting
double roundPriceToTickForTest(double price, double tickSize) {
  if (tickSize <= 0) return price;
  final n = (price / tickSize).roundToDouble();
  final v = n * tickSize;
  // format to tick precision to avoid floating artifacts
  int scale = 0;
  double x = tickSize.abs();
  if (x != 0) {
    while ((x - x.roundToDouble()).abs() > 1e-12 && scale < 12) {
      x *= 10.0;
      scale++;
    }
  }
  return double.parse(v.toStringAsFixed(scale));
}

@visibleForTesting
double roundQtyToStepForTest(double qty, double stepSize) {
  if (stepSize <= 0) return qty;
  // Stabilize division to avoid 0.5 drifting below midpoint due to FP error
  final unitsRaw = qty / stepSize;
  final units = double.parse(unitsRaw.toStringAsFixed(12));
  final n = units.roundToDouble();
  final v = n * stepSize;
  // format to step precision to avoid floating artifacts
  final scale = ExchangeRules._scaleFromStep(stepSize);
  return double.parse(v.toStringAsFixed(scale));
}

@visibleForTesting
double clampMinNotionalForTest({
  required double qty,
  required double price,
  required double minNotional,
}) {
  final notional = qty * price;
  if (notional >= minNotional) return qty;
  final needed = (minNotional / price);
  return double.parse(needed.toStringAsFixed(8));
}

extension ExchangeRulesForTest on ExchangeRules {
  static ExchangeRules forTest({
    required double minNotional,
    required double qtyStep,
    required double priceTick,
  }) {
    return ExchangeRules(
      priceScale: ExchangeRules._scaleFromStep(priceTick),
      qtyScale: ExchangeRules._scaleFromStep(qtyStep),
      tickSize: priceTick,
      stepSize: qtyStep,
      minNotional: minNotional,
    );
  }
}
