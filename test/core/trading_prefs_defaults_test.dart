import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TradingPrefs returns sensible defaults when unset', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    expect(await p.getApiKey(), isNull);
    expect(await p.getApiSecret(), isNull);
    expect(await p.getEnv(), 'testnet');
    expect(await p.getDefaultQuote(), isNull);
  });
}


