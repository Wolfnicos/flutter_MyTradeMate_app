import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseKlinesForTest handles mixed string/num values and preserves rows', () {
    final c = DioBinanceClient.fakeForTest();
    final raw = [
      // [openTime, o, h, l, c, v, closeTime, q, n, takerBuyBase, takerBuyQuote, ignore]
      [0, 0, 0, 0, '1000.0', 0, 0, 0, 0, 0, 0, 0], // close as string
      [0, 0, 0, 0, 1001.0,   0, 0, 0, 0, 0, 0, 0], // close as num
    ];

    final kl = c.parseKlinesForTest(raw);
    expect(kl.length, 2);
    expect(kl[0][4], '1000.0');
    expect(kl[1][4], 1001.0);
    expect(kl[0] is List<dynamic>, isTrue);
    expect(kl[1] is List<dynamic>, isTrue);
  });
}


