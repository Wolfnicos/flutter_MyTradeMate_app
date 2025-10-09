import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/explain.dart';

void main() {
  test('mapToExplain preserves metrics and features', () {
    final seq = List.generate(64, (i) => <double>[i.toDouble(), i + 1.0]);
    final d = mapToExplain(
      'ETHUSDT',
      seq,
      asOf: DateTime.utc(2025, 1, 5, 12),
      pBuy: 0.61,
      expReturn: 0.013,
      annVol: 0.12,
      modelRev: 'r-test',
    );
    expect(d.symbol, 'ETHUSDT');
    expect(d.pBuy, 0.61);
    expect(d.expReturn, 0.013);
    expect(d.annVol, 0.12);
    expect(d.features.length, 64);
    expect(d.features.first.length, 2);
  });
}
