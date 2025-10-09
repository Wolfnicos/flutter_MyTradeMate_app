import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/price_stream.dart';

void main() {
  test('backoffForAttempt caps at 30s and grows 1,2,5,10,20,30', () {
    expect(PriceStream.backoffForAttempt(1).inSeconds, 1);
    expect(PriceStream.backoffForAttempt(2).inSeconds, 2);
    expect(PriceStream.backoffForAttempt(3).inSeconds, 5);
    expect(PriceStream.backoffForAttempt(4).inSeconds, 10);
    expect(PriceStream.backoffForAttempt(5).inSeconds, 20);
    expect(PriceStream.backoffForAttempt(6).inSeconds, 30);
    expect(PriceStream.backoffForAttempt(100).inSeconds, 30);
  });

  test('shouldTripCircuit after >= maxFailures', () {
    expect(PriceStream.shouldTripCircuit(5, maxFailures: 6), isFalse);
    expect(PriceStream.shouldTripCircuit(6, maxFailures: 6), isTrue);
    expect(PriceStream.shouldTripCircuit(10, maxFailures: 6), isTrue);
  });
}



