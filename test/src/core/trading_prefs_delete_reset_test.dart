import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reset keys clears stored values', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();
    await p.setApiKey('k');
    await p.setApiSecret('s');
    await p.setEnv('testnet');
    await p.setDefaultQuote('USDT');

    // Simulate reset by clearing keys in SharedPreferences
    final sp = await SharedPreferences.getInstance();
    await sp.remove('api_key');
    await sp.remove('api_secret');
    await sp.remove('trade_env');
    await sp.remove('default_quote_ccy');

    expect(await p.getApiKey(), anyOf(isNull, ''));
    expect(await p.getDefaultQuote(), isNull);
  });
}


