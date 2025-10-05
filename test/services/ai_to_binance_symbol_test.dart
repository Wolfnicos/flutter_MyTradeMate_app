import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('_toBinanceSymbol normalizes', () {
    expect(toBinanceSymbolForTest('btc/usdt'), 'BTCUSDT');
    expect(toBinanceSymbolForTest('ethusd'), 'ETHUSDT');
    expect(toBinanceSymbolForTest(' BNB / USD '), 'BNBUSDT');
  });
}


