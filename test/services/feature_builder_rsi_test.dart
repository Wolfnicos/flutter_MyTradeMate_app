import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/feature_builder.dart';

void main() {
  test('RSI boundaries in sequenceFromCloses', () {
    const fb = FeatureBuilder();
    // flat series → RSI ~50
    final flat = List<double>.filled(64, 100.0);
    final seqFlat = fb.sequenceFromCloses(flat, length: 64);
    expect(seqFlat.last[4], inInclusiveRange(49.0, 51.0));

    // strictly increasing → RSI near 100
    final inc = List<double>.generate(64, (i) => 100.0 + i);
    final seqInc = fb.sequenceFromCloses(inc, length: 64);
    expect(seqInc.last[4], greaterThan(90));

    // strictly decreasing → RSI near 0
    final dec = List<double>.generate(64, (i) => 100.0 - i);
    final seqDec = fb.sequenceFromCloses(dec, length: 64);
    expect(seqDec.last[4], lessThan(10));
  });
}



