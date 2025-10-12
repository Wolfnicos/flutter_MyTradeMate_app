import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setDefaultQuote trims, uppercases and ignores empty', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    await p.setDefaultQuote('  usdt  ');
    expect(await p.getDefaultQuote(), 'USDT');

    await p.setDefaultQuote(''); // ignored
    expect(await p.getDefaultQuote(), 'USDT'); // unchanged
  });
}
