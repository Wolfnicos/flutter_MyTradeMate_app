import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:test/test.dart' as test show Skip;

@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  test('_toBinanceSymbol normalizes', () {
    expect(toBinanceSymbolForTest('btc/usdt'), 'BTCUSDT');
    expect(toBinanceSymbolForTest('ethusd'), 'ETHUSDT');
    expect(toBinanceSymbolForTest(' BNB / USD '), 'BNBUSDT');
  });
}
