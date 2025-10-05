import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('mapToExplain preserves AiResult metrics and features', () {
    final seq = List.generate(64, (i) => <double>[i.toDouble(), i + 1.0]);
    final r = AIPrediction(
      action: 'BUY',
      confidence: 61.0,
      targetPrice: 1234.56,
      volatility: 'HIGH',
      probUp: 0.61,
      nextReturn: 0.013,
      volatilityValue: 0.12,
    );
    final d = mapToExplain('ETHUSDT', seq, r);
    expect(d.symbol, 'ETHUSDT');
    expect(d.probUp, r.probUp);
    expect(d.nextReturn, r.nextReturn);
    expect(d.volatility, r.volatilityValue);
    expect(d.volatilityLabel, r.volatility);
    expect(d.features.length, 64);
    expect(d.features.first.length, 2);
  });
}


