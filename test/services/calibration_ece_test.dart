import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/calibration.dart';

void main() {
  test('Reliability bins and ECE compute as expected on synthetic', () {
    final p = <double>[0.1, 0.2, 0.3, 0.8, 0.9, 0.95];
    final y = <int>[0, 0, 1, 1, 1, 1];
    final bins = reliabilityBins(p, y, bins: 5);
    expect(bins, isNotEmpty);
    final e = expectedCalibrationError(bins, p.length);
    expect(e, greaterThanOrEqualTo(0.0));
    expect(e, lessThanOrEqualTo(1.0));
  });
}



