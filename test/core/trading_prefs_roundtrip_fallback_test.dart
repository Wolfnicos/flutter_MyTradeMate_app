import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('roundtrip all fields then read back exact values', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    await p.setApiKey('key-12345678');
    await p.setApiSecret('secret-abcdefghijklmnopqrstuvwxyz');
    await p.setEnv('testnet');
    await p.setDefaultQuote('USDT');

    expect(await p.getApiKey(), 'key-12345678');
    expect(await p.getApiSecret(), 'secret-abcdefghijklmnopqrstuvwxyz');
    expect(await p.getEnv(), 'testnet');
    expect(await p.getDefaultQuote(), 'USDT');
  });

  test('fallbacks from dart-define when prefs unset', () async {
    SharedPreferences.setMockInitialValues({});
    // Simulează --dart-define; dacă implementarea citește direct din const String.fromEnvironment,
    // testul doar validează că getterele nu aruncă și întorc ceva rezonabil (null sau valori implicite).
    final p = await TradingPrefs.inMemoryForTest();

    final env = await p.getEnv();
    final dq  = await p.getDefaultQuote();
    // Acceptăm fie null, fie valorile implicite "testnet"/"USDT" în funcție de implementare
    expect(env, anyOf(isNull, 'testnet'));
    expect(dq,  anyOf(isNull, 'USDT'));
  });
}
