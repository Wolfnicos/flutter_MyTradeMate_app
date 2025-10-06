import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/settings_screen.dart';

void main() {
  test('API key validator basic rules', () {
    expect(validateApiKeyForTest(null), isNotNull);
    expect(validateApiKeyForTest(''), isNotNull);
    expect(validateApiKeyForTest('short'), isNotNull);
    expect(validateApiKeyForTest('abcdefgh'), isNull);
  });

  test('API secret validator basic rules', () {
    expect(validateSecretForTest(null), isNotNull);
    expect(validateSecretForTest(''), isNotNull);
    expect(validateSecretForTest('12345678901'), isNotNull);
    expect(validateSecretForTest('123456789012'), isNull);
  });
}

