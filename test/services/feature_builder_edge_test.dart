import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/feature_builder.dart';

void main() {
  test('fromTicker fills missing values and computes ret1', () {
    const fb = FeatureBuilder();
    final m = fb.fromTicker(last: 110.0, prev: 100.0);
    expect(m['last'], 110.0);
    expect(m['ret1'], closeTo(0.1, 1e-9));
    expect(m['sma5'], 110.0);
    expect(m['sma20'], 110.0);
    expect(m['rsi14'], 50.0);
  });

  test('sequenceFromCloses trims and pads', () {
    const fb = FeatureBuilder();
    final seqShort = fb.sequenceFromCloses([1, 2, 3], length: 5);
    expect(seqShort.length, 5);
    expect(seqShort.first[0], 1); // padded with first value

    final seqLong = fb.sequenceFromCloses([1, 2, 3, 4, 5, 6], length: 5);
    expect(seqLong.length, 5);
    // last window kept
    expect(seqLong.last[0], 6);
  });
}
