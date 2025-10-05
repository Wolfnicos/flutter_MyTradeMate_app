import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream.dart';

void main() {
  test('PriceStream constructs and can be stopped without connection', () {
    final ps = PriceStream(symbol: 'BTCUSDT', testnet: true);
    // Do not call start() to avoid network; just exercise stop/dispose paths
    ps.stop();
    expect(ps.prices, isA<Stream<double>>());
  });
}


