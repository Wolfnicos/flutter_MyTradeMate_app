import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/obs/prediction_trace.dart';
import 'package:mytrademate/obs/log_sink.dart';
import 'package:mytrademate/ai/entities.dart' as ai;

void main() {
  test('PredictionTracer writes a valid JSON line', () async {
    final sink = InMemorySink();
    final tracer = PredictionTracer(sink);

    final pred = ai.Prediction(
      symbol: 'BTCUSDT',
      pBuy: 0.71,
      pHold: 0.19,
      pSell: 0.10,
      expReturn: 0.0035,
      annVol: 0.19,
      relVolume: 1.0,
      asOf: DateTime.utc(2025,1,1,12),
    );

    await tracer.log(
      pred: pred,
      modelRev: 'r-test',
      features: const [1.0, 2.0, 3.0],
      fp16Flags: const {'dir': false, 'ret': true, 'vol': false},
    );

    expect(sink.lines.length, 1);
    final m = sink.lines.first;
    expect(m['symbol'], 'BTCUSDT');
    expect(m['modelRev'], 'r-test');
    expect(m['pBuy'], isA<num>());
    expect(m['meta'], isA<Map>());
    expect((m['meta'] as Map)['featuresHash'], isA<String>());
  });
}


