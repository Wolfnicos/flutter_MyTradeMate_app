import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('isPrimitiveQueryValueForTest accepts negative numbers and empty strings; rejects others', () {
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(-42), isTrue);      // negative int
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(-3.14), isTrue);    // negative double
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(''), isTrue);       // empty string

    expect(DioBinanceClient.isPrimitiveQueryValueForTest(null), isFalse);    // null
    expect(DioBinanceClient.isPrimitiveQueryValueForTest([]), isFalse);      // list
    expect(DioBinanceClient.isPrimitiveQueryValueForTest({}), isFalse);      // map
  });
}


