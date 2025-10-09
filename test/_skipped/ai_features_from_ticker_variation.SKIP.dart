import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:test/test.dart' as test show Skip;
@test.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')

void main() {
  test('featuresFromTickerForTest changes when last price changes', () {
    final a = featuresFromTickerForTest(1000.0);
    final b = featuresFromTickerForTest(1100.0);
    expect(a.length, 64);
    expect(b.length, 64);
    expect(a.first, isNot(equals(b.first)));
  });
}


