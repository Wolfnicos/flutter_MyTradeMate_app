import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('when prefs empty, getters do not throw and return sensible defaults',
      () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    final env = await p.getEnv();
    final dq = await p.getDefaultQuote();
    final key = await p.getApiKey();
    final sec = await p.getApiSecret();

    // Accept null/defaults depending on implementation; should not throw
    expect(env, anyOf(isNull, 'testnet'));
    expect(dq, anyOf(isNull, 'USDT'));
    expect(key, anyOf(isNull, isA<String>()));
    expect(sec, anyOf(isNull, isA<String>()));
  });
}
