import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/feature_builder.dart';

void main() {
  test('sequenceFromCloses handles short input via left-padding', () {
    const fb = FeatureBuilder();
    final closes = <double>[1000, 1001, 1002];
    final seq = fb.sequenceFromCloses(closes, length: 64);
    expect(seq.length, 64);
    for (final row in seq) {
      for (final v in row) {
        expect(v.isFinite, true);
      }
    }
  });
}



