import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/calibration.dart';

void main() {
  test('Identity clamps to [0,1]', () {
    const id = IdentityCalibrator();
    expect(id.calibrate(-0.1), 0.0);
    expect(id.calibrate(0.5), 0.5);
    expect(id.calibrate(1.5), 1.0);
  });

  test('Platt maps via sigmoid with a,b', () {
    const pl = PlattCalibrator(2.0, -1.0);
    final v = pl.calibrate(0.5);
    expect(v, greaterThan(0.0));
    expect(v, lessThan(1.0));
  });

  test('Isotonic linear interpolation on bins', () {
    final iso = IsotonicCalibrator([0.0, 0.5, 1.0], [0.0, 0.4, 1.0]);
    expect(iso.calibrate(-0.1), 0.0);
    expect(iso.calibrate(0.0), 0.0);
    expect(iso.calibrate(0.25), closeTo(0.2, 1e-6));
    expect(iso.calibrate(0.5), 0.4);
    expect(iso.calibrate(0.75), closeTo(0.7, 1e-6));
    expect(iso.calibrate(1.0), 1.0);
    expect(iso.calibrate(1.5), 1.0);
  });
}


