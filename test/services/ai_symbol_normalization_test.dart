import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('toBinanceSymbolForTest normalizes whitespace, slash and case', () {
    expect(toBinanceSymbolForTest(' btc/usdt '), 'BTCUSDT');
    expect(toBinanceSymbolForTest('Eth Usdt'), 'ETHUSDT');
    expect(toBinanceSymbolForTest('SOL/USDT'), 'SOLUSDT');
  });
}

