import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/trading_modal.dart';

void main() {
  test('validateQuoteForTest catches null/zero/negative', () {
    expect(validateQuoteForTest(null), isNotNull);
    expect(validateQuoteForTest(0), isNotNull);
    expect(validateQuoteForTest(-1), isNotNull);
    expect(validateQuoteForTest(10), isNull);
  });
}
