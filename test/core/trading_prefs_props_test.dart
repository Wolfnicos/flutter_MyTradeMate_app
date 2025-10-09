import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasCreds toggles with api key/secret and fixedQuote defaults/sets',
      () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    // Initially no creds
    expect(p.hasCreds, isFalse);
    // Default fixedQuote falls back to 50.0 when no env/default set
    expect(p.fixedQuote, 50.0);

    // Set credentials and fixed quote through save
    await p.save(
        apiKey: 'k123',
        apiSecret: 's456',
        env: TradeEnv.testnet,
        fixedQuote: 25.0);
    expect(p.hasCreds, isTrue);
    expect(p.fixedQuote, 25.0);
  });
}



