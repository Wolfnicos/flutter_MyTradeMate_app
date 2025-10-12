import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/explain.dart';

void main() {
  test('mapToExplain carries raw outputs and features', () {
    final seq = List.generate(64, (_) => [0.0, 1.0, 2.0]);
    final ex = mapToExplain(
      'BTCUSDT',
      seq,
      asOf: DateTime.utc(2025, 1, 1),
      pBuy: 0.56,
      expReturn: 0.01,
      annVol: 0.05,
    );
    expect(ex.symbol, 'BTCUSDT');
    expect(ex.pBuy, closeTo(0.56, 1e-9));
    expect(ex.expReturn, closeTo(0.01, 1e-9));
    expect(ex.annVol, closeTo(0.05, 1e-9));
    expect(ex.volatilityLabel, 'MEDIUM');
    expect(ex.features.length, 64);
  });
}
