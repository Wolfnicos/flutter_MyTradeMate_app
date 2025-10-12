import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TradingPrefs read/write and env defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.load();
    // defaults
    expect(p.env, TradeEnv.testnet);
    expect(p.fixedQuote, 50.0);

    await p.save(
        apiKey: 'k', apiSecret: 's', env: TradeEnv.live, fixedQuote: 75.0);
    expect(p.apiKey, 'k');
    expect(p.apiSecret, 's');
    expect(p.env, TradeEnv.live);
    expect(p.fixedQuote, 75.0);
  });
}
