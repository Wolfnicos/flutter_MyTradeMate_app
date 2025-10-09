import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/models/signal.dart';

void main() {
  test('Signal toJson/fromJson roundtrip', () {
    const s = Signal(
        nextReturn: 0.02, probUp: 0.6, volatility: 0.01, dir: Direction.up);
    final j = s.toJson();
    final s2 = Signal.fromJson({
      'nextReturn': j['nextReturn'],
      'probUp': j['probUp'],
      'volatility': j['volatility'],
      'dir': 'up',
    });
    expect(s2.nextReturn, 0.02);
    expect(s2.probUp, 0.6);
    expect(s2.volatility, 0.01);
    expect(s2.dir, Direction.up);
  });
}



