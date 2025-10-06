import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseKlinesForTest preserves empty/short rows without throwing', () {
    final c = DioBinanceClient.fakeForTest();
    final raw = [
      [], // empty row
      [0, 0, 0, 0, '1002.0'], // short row (close string)
      [0, 0, 0, 0, 1003.0, 0, 0, 0, 0], // longer row (close num)
    ];

    final kl = c.parseKlinesForTest(raw);

    expect(kl.length, 3);
    expect(kl[0], isA<List<dynamic>>());
    expect((kl[0]).isEmpty, isTrue);

    expect(kl[1], isA<List<dynamic>>());
    expect((kl[1]).length, 5);
    expect(kl[1][4], '1002.0');

    expect(kl[2], isA<List<dynamic>>());
    expect((kl[2]).length, greaterThanOrEqualTo(5));
    expect(kl[2][4], 1003.0);
  });
}

