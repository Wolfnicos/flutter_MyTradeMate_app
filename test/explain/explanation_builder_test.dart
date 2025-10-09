import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/core/explain/explanation_builder.dart';

void main() {
  test('builds safe copy with valid confidence', () {
    final out = ExplanationBuilder.build(ExplanationInput(
      direction: Direction.up,
      volLevel: VolLevel.high,
      confidence: 0.82,
      topFactors: const ['momentum_5m', 'rv_30m'],
      dataGaps: false,
      lastTickAge: const Duration(seconds: 2),
      isPaperMode: true,
    ));
    expect(out.headline.contains('Confidence 82%'), true);
    expect(out.advisory.contains('Paper/Testnet'), true);
    expect(out.dataGap, isNull);
  });

  test('falls back when confidence missing', () {
    final out = ExplanationBuilder.build(ExplanationInput(
      direction: Direction.flat,
      volLevel: VolLevel.moderate,
      confidence: null,
      topFactors: const [],
      dataGaps: true,
      lastTickAge: const Duration(seconds: 10),
      isPaperMode: false,
    ));
    expect(out.headline.contains('can’t reliably estimate'), true);
    expect(out.dataGap, isNotNull);
  });
}



