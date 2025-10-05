import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/src/core/trading_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setDefaultQuote normalizes to uppercase and ignores empty', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await TradingPrefs.inMemoryForTest();

    await p.setDefaultQuote('  usdt  ');
    expect(await p.getDefaultQuote(), 'USDT');

    // empty -> should not overwrite existing value
    await p.setDefaultQuote('   ');
    expect(await p.getDefaultQuote(), 'USDT');
  });
}


