import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TradingPrefs full read/write', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    await p.setApiKey('abcd1234');
    await p.setApiSecret('very-secret-xyz');
    await p.setEnv('testnet');
    await p.setDefaultQuote('USDT');

    expect(await p.getApiKey(), 'abcd1234');
    expect(await p.getApiSecret(), 'very-secret-xyz');
    expect(await p.getEnv(), 'testnet');
    expect(await p.getDefaultQuote(), 'USDT');
  });
}



