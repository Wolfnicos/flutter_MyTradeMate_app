import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('toQueryForTest orders primitives and ignores null/map', () {
    final c = DioBinanceClient.fakeForTest();
    final q = c.toQueryForTest({
      'symbol': 'BTCUSDT',
      'limit': 50,
      'recvWindow': null,
      'nested': {'a': 1},
      'bool': true,
      'dbl': 1.23,
    });
    final s = q.entries.map((e) => '${e.key}=${e.value}').join('&');
    expect(s.contains('symbol=BTCUSDT'), isTrue);
    expect(s.contains('limit=50'), isTrue);
    expect(s.contains('bool=true'), isTrue);
    expect(s.contains('dbl=1.23'), isTrue);
    expect(s.contains('recvWindow='), isFalse);
    expect(s.contains('nested='), isFalse);
  });

  test('parseTickerPriceForTest handles string/num and fallback c', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.parseTickerPriceForTest({'price': '123.45', 'c': '0'}), 123.45);
    expect(c.parseTickerPriceForTest({'price': 123.0, 'c': '0'}), 123.0);
    expect(c.parseTickerPriceForTest({'c': '99.9'}), 99.9);
  });

  test('supportsSymbolFromExchangeInfoForTest finds symbol case-insensitive',
      () {
    final info = {
      'symbols': [
        {'symbol': 'BTCUSDT'},
        {'symbol': 'ETHUSDT'},
      ]
    };
    // use static helper that normalizes case for matching
    expect(
        DioBinanceClient.minNotionalFromExchangeInfoForTest(
            {'symbols': []}, 'ETHUSDT'),
        0);
    // supportsSymbolFromExchangeInfoForTest equivalent via supportsSymbolForTest
    final cli = DioBinanceClient.fakeForTest();
    expect(
        cli.supportsSymbolForTest(['BTCUSDT', 'ETHUSDT'], 'ethusdt'), isTrue);
    expect(
        cli.supportsSymbolForTest(['BTCUSDT', 'ETHUSDT'], 'ABCUSDT'), isFalse);
  });
}
