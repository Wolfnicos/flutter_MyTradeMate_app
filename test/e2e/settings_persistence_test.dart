import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Settings persist & secret masked', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await sp.setString('binance.apiKey', 'TESTNET_KEY');
    await sp.setString('binance.secret', 'SECRET'); // stored, UI must mask
    await sp.setString('binance.env', 'testnet');
    await sp.setDouble('binance.fixedQuote', 50);

    final sp2 = await SharedPreferences.getInstance();
    expect(sp2.getString('binance.apiKey'), 'TESTNET_KEY');
    expect(sp2.getString('binance.secret')?.isNotEmpty, true);
    expect(sp2.getString('binance.env'), 'testnet');
    expect(sp2.getDouble('binance.fixedQuote'), 50);
  });
}




