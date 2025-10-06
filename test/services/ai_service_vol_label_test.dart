import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('volLabel thresholds LOW/MEDIUM/HIGH', () {
    expect(volLabelForTest(0.0), 'LOW');
    expect(volLabelForTest(0.0299), 'LOW');
    expect(volLabelForTest(0.03), 'MEDIUM');
    expect(volLabelForTest(0.0999), 'MEDIUM');
    expect(volLabelForTest(0.10), 'HIGH');
    expect(volLabelForTest(0.25), 'HIGH');
  });
}

