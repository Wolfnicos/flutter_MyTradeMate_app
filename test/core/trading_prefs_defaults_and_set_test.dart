import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults then set and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();
    expect(await p.getEnv(), anyOf(isNull, 'testnet'));

    await p.setEnv('testnet');
    await p.setDefaultQuote('USDT');
    await p.setApiKey('abcd1234');
    await p.setApiSecret('very-secret');

    expect(await p.getEnv(), 'testnet');
    expect(await p.getDefaultQuote(), 'USDT');
    expect(await p.getApiKey(), 'abcd1234');
    expect(await p.getApiSecret(), 'very-secret');
  });
}



