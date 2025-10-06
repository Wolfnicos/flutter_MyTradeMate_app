import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TradingPrefs stores and reads keys/env/quote', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await TradingPrefs.inMemoryForTest();

    await prefs.setApiKey('abcd1234');
    await prefs.setApiSecret('very-long-secret-123');
    await prefs.setEnv('testnet');
    await prefs.setDefaultQuote('USDT');

    expect(await prefs.getApiKey(), 'abcd1234');
    expect(await prefs.getApiSecret(), 'very-long-secret-123');
    expect(await prefs.getEnv(), 'testnet');
    expect(await prefs.getDefaultQuote(), 'USDT');
  });
}

