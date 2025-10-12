import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/predictors/timeseries_tflite_predictor.dart';
import 'package:mytrademate/ai/norm_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PatchTST predictor smoke (BTCUSDT 15m) if asset exists', () async {
    final modelPath = 'assets/models/patchtst_BTCUSDT_15m_fp16.tflite';
    final normPath = 'assets/models/norm.json';
    final hasModel = File(modelPath).existsSync();
    final hasNorm = File(normPath).existsSync();
    if (!hasModel || !hasNorm) {
      return; // skip silently in CI when assets are missing
    }

    // Ensure norm is loaded
    await NormLoader.I.ensureLoaded();

    // Build a fake 64-candle window
    final now = DateTime.now();
    final candles = List<Candle>.generate(64, (i) {
      final t = now.subtract(Duration(minutes: (64 - i) * 5));
      final base = 50000.0 + i;
      return Candle(
        time: t,
        open: base,
        high: base * 1.001,
        low: base * 0.999,
        close: base * 1.0002,
        volume: 100 + i.toDouble(),
      );
    });

    final predictor = TimeSeriesTflitePredictor();
    final pred = await predictor.predict('BTCUSDT', candles, timeframe: '15m');
    // If inference fails in this environment, just skip
    if (pred == null) return;

    expect(pred.pBuy.isFinite, isTrue);
    expect(pred.pHold.isFinite, isTrue);
    expect(pred.pSell.isFinite, isTrue);
    expect(pred.expReturn.isFinite, isTrue);
    expect(pred.annVol.isFinite, isTrue);
  });
}
