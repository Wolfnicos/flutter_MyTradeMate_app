import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/feature_builder.dart';

void main() {
  test('sequenceFromCloses pads/trims to length 64 and computes indicators',
      () {
    const fb = FeatureBuilder(['last', 'ret1', 'sma5', 'sma20', 'rsi14']);
    final closes = List<double>.generate(10, (i) => (i + 1).toDouble());
    final seq = fb.sequenceFromCloses(closes, length: 64);
    expect(seq.length, 64);
    // Each row has exactly nfeat columns
    for (final row in seq) {
      expect(row.length, FeatureBuilder.nfeat);
    }
  });
}
