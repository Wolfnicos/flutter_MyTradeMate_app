import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/screens/settings_screen.dart';

void main() {
  test('Settings validators cover invalid and valid cases', () {
    // API key
    expect(validateApiKeyForTest(null), isNotNull);
    expect(validateApiKeyForTest(' '), isNotNull);
    expect(validateApiKeyForTest('abc123'), isNotNull);
    expect(validateApiKeyForTest('abcd1234'), isNull);

    // Secret
    expect(validateSecretForTest(null), isNotNull);
    expect(validateSecretForTest('short'), isNotNull);
    expect(validateSecretForTest('very-long-secret-123'), isNull);
  });
}
