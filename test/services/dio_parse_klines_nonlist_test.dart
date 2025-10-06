import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/dio_binance_client.dart';

void main() {
  test('parseKlinesForTest returns empty list on non-List input', () {
    final c = DioBinanceClient.fakeForTest();
    expect(c.parseKlinesForTest(null), isEmpty);
    expect(c.parseKlinesForTest({'not': 'a list'}), isEmpty);
    expect(() => c.parseKlinesForTest(123), returnsNormally);
  });

  test('parseKlinesForTest tolerates mixed rows', () {
    final c = DioBinanceClient.fakeForTest();
    final out = c.parseKlinesForTest([
      [1, '2', 3.0],
      'not a row',
      [],
    ]);
    expect(out.length, 3);
    expect(out[0], isA<List<dynamic>>());
    expect(out[1], isA<List<dynamic>>());
    expect(out[2], isA<List<dynamic>>());
  });
}
