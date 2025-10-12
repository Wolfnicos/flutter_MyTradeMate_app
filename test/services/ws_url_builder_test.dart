import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/binance_ws_url.dart';

void main() {
  test('testnet URL for BTCUSDT is correct', () {
    final uri = binanceWsUrl('BTCUSDT', testnet: true);
    expect(
        uri.toString(), 'wss://testnet.binance.vision/ws/btcusdt@miniTicker');
  });

  test('mainnet URL for BTCUSDT is correct', () {
    final uri = binanceWsUrl('BTCUSDT', testnet: false);
    expect(
        uri.toString(), 'wss://stream.binance.com:9443/ws/btcusdt@miniTicker');
  });
}
