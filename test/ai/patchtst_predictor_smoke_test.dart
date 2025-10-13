import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mytrademate/ai/predictors/timeseries_tflite_predictor.dart';
import 'package:mytrademate/ai/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TimeSeries predictor smoke: finite probs and softmax-ish', () async {
    // Check asset presence (gate)
    try {
      await rootBundle.load('assets/models/patchtst_BTCUSDT_5m_fp16.tflite');
    } catch (_) {
      // Asset not present in this environment; skip
      return;
    }

    // Build a dummy candle window (monotonic increasing)
    final now = DateTime.now().subtract(const Duration(minutes: 5 * 96));
    final List<Candle> window = List.generate(96, (i) {
      final t = now.add(Duration(minutes: i * 5));
      final base = 10000.0 + i.toDouble();
      return Candle(
        time: t,
        open: base,
        high: base * 1.001,
        low: base * 0.999,
        close: base * (1.0 + (i % 3) * 0.0001),
        volume: 10.0 + (i % 5),
      );
    });

    final pred = await TimeSeriesTflitePredictor().predict('BTCUSDT', window, timeframe: '5m');
    // If interpreter is unavailable on this platform, pred may be null
    if (pred == null) return;

    // Probs finite and in [0,1]
    expect(pred.pBuy, inInclusiveRange(0.0, 1.0));
    expect(pred.pHold, inInclusiveRange(0.0, 1.0));
    expect(pred.pSell, inInclusiveRange(0.0, 1.0));
    final sum = pred.pBuy + pred.pHold + pred.pSell;
    expect(sum, greaterThan(0));
    expect(sum, lessThanOrEqualTo(1.001));

    // expReturn and annVol finite
    expect(pred.expReturn.isFinite, isTrue);
    expect(pred.annVol.isFinite, isTrue);
  });
}
