import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('accepts only num/bool/string and rejects list/map/other', () {
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(42), isTrue);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(3.14), isTrue);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(true), isTrue);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest('ok'), isTrue);

    expect(DioBinanceClient.isPrimitiveQueryValueForTest(null), isFalse);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest([1, 2]), isFalse);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest({'k': 'v'}), isFalse);
    expect(DioBinanceClient.isPrimitiveQueryValueForTest(Object()), isFalse);
  });
}

