import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:test/test.dart' as test show Skip;

@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  test('featuresFromTickerForTest builds a 64×N sequence', () {
    final seq = featuresFromTickerForTest(1234.5);
    expect(seq.length, 64);
    expect(seq.first.isNotEmpty, true);
  });
}
