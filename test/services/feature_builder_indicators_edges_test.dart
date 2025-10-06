import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'dart:math' as math;

void main() {
  test('RSI handles flat series and short inputs without NaN', () {
    const fb = FeatureBuilder();
    final closes = List<double>.filled(20, 1000.0);
    final seq = fb.sequenceFromCloses(closes, length: 64);
    for (final row in seq) {
      for (final v in row) {
        expect(v.isFinite, true);
      }
    }
  });

  test('SMA/sequence stable on noisy series', () {
    const fb = FeatureBuilder();
    final closes =
        List<double>.generate(64, (i) => 1000 + math.sin(i / 3.14) * 5);
    final seq = fb.sequenceFromCloses(closes, length: 64);
    expect(seq.length, 64);
    for (final row in seq) {
      for (final v in row) {
        expect(v.isFinite, true);
      }
    }
  });
}

