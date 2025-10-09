import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/trading_modal.dart';

void main() {
  test('validateQuote basic rules', () {
    expect(validateQuoteForTest(null), isNotNull);
    expect(validateQuoteForTest(0), isNotNull);
    expect(validateQuoteForTest(-1), isNotNull);
    expect(validateQuoteForTest(0.01), isNull);
  });
}



