import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('clamps up to min notional when below threshold', () {
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 9.999, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 10, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 12.34, minNotional: 10),
      12.34,
    );
  });

  test('handles zero/negative inputs safely', () {
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 0, minNotional: 10),
      10,
    );
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: -5, minNotional: 10),
      10,
    );
    // minNotional zero => does not force increase
    expect(
      DioBinanceClient.clampToMinNotionalForTest(quote: 0, minNotional: 0),
      0,
    );
  });
}



