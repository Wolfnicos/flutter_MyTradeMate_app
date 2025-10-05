import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('featuresFromTickerForTest builds a 64×N sequence', () {
    final seq = featuresFromTickerForTest(1234.5);
    expect(seq.length, 64);
    expect(seq.first.isNotEmpty, true);
  });
}


