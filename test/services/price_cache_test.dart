import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_cache.dart';

void main() {
  test('put/get and overwrite are consistent', () {
    final c = PriceCache();
    expect(c.get('BTCUSDT'), isNull);
    c.put('BTCUSDT', 60000);
    expect(c.get('btcusdt'), 60000);
    c.put('BTCUSDT', 61000);
    expect(c.get('BTCUSDT'), 61000);
  });
}



