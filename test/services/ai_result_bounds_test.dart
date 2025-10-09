import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/explain.dart';

void main() {
  test(
      'confidence is bounded [0,100] and target uses nextReturn (mapping only)',
      () {
    final d = mapToExplain('BTCUSDT', List.generate(64, (_) => <double>[1.0]),
        asOf: DateTime.utc(2025,1,1), pBuy: 1.2, expReturn: 0.05, annVol: 0.12);
    expect(d.pBuy, 1.2);
    expect(d.expReturn, 0.05);
  });
}


