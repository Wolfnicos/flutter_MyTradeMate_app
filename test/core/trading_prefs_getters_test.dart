import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync getters reflect SharedPreferences values', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    // Initially null
    expect(p.apiKey, isNull);
    expect(p.apiSecret, isNull);
    // Default env is testnet when unset
    expect(p.env, TradeEnv.testnet);

    await p.save(
        apiKey: 'KEY', apiSecret: '', env: TradeEnv.live, fixedQuote: 12.5);
    // Empty secret keeps hasCreds false
    expect(p.apiKey, 'KEY');
    expect(p.apiSecret, isNull);
    expect(p.env, TradeEnv.live);
    expect(p.fixedQuote, 12.5);

    await p.save(apiSecret: 'SECRET');
    expect(p.apiSecret, 'SECRET');
    expect(p.hasCreds, isTrue);
  });
}
