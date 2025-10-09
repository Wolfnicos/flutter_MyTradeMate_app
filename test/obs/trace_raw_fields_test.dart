import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/obs/prediction_trace.dart';
import 'package:mytrademate/obs/log_sink.dart';
import 'package:mytrademate/ai/entities.dart' as ai;

void main() {
  test('Trace contains vol_raw and ret_raw', () async {
    final sink = InMemorySink();
    final tracer = PredictionTracer(sink);

    final pred = ai.Prediction(
      symbol: 'BTCUSDT',
      asOf: DateTime.utc(2025, 1, 1, 12),
      pBuy: 0.6,
      pHold: 0.2,
      pSell: 0.2,
      expReturn: 0.0042,
      annVol: 0.18,
      relVolume: 1.0,
    );

    await tracer.log(
      pred: pred,
      modelRev: 'r-test',
      features: const [1.0, 2.0, 3.0],
      fp16Flags: const {'dir': false, 'ret': false, 'vol': false},
    );

    expect(sink.lines.length, 1);
    final m = sink.lines.first;
    expect(m['meta'], isA<Map>());
    final meta = m['meta'] as Map;
    expect(meta.containsKey('vol_raw'), isTrue);
    expect(meta.containsKey('ret_raw'), isTrue);
    expect(meta.containsKey('vol_fallback_used'), isTrue);
  });
}



