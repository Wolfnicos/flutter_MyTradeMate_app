import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseBalancesForTest transforms strings/nums and filters zero totals',
      () {
    final c = DioBinanceClient.fakeForTest();
    final account = {
      'balances': [
        {'asset': 'BTC', 'free': '0.01', 'locked': '0.00'},
        {'asset': 'ETH', 'free': 0.0, 'locked': 0.0},
        {'asset': 'USDT', 'free': '25', 'locked': '5'},
      ]
    };
    final balances = c.parseBalancesForTest(account);
    expect(balances.length, 2);
    expect(balances.first['asset'], 'BTC');
    expect(balances.last['asset'], 'USDT');
    expect(balances.last['free'], 25.0);
    expect(balances.last['locked'], 5.0);
  });

  test('toHoldingsForTest maps with prices, ignores unknown assets', () {
    final c = DioBinanceClient.fakeForTest();
    final balances = [
      {'asset': 'BTC', 'free': 0.01, 'locked': 0.0},
      {'asset': 'XYZ', 'free': 10.0, 'locked': 0.0},
      {'asset': 'USDT', 'free': 30.0, 'locked': 0.0},
    ];
    final prices = {'BTCUSDT': 60000.0};
    final holdings = c.toHoldingsForTest(balances, prices);
    expect(holdings.length, 2); // BTC and USDT
    final btc = holdings.firstWhere((h) => h['asset'] == 'BTC');
    expect(btc['valueUsdt'], closeTo(0.01 * 60000, 1e-6));
    final usdt = holdings.firstWhere((h) => h['asset'] == 'USDT');
    expect(usdt['valueUsdt'], 30.0);
  });
}
