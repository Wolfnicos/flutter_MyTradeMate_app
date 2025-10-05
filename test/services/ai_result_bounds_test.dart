import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('confidence is bounded [0,100] and target uses nextReturn (mapping only)', () {
    const r = AIPrediction(
      action: 'BUY',
      confidence: 123.0,
      targetPrice: 0.0,
      volatility: 'HIGH',
      probUp: 1.2,
      nextReturn: 0.05,
      volatilityValue: 0.12,
    );
    final d = mapToExplain('BTCUSDT', List.generate(64, (_) => <double>[1.0]), r);
    expect(d.probUp, 1.2);
    expect(d.nextReturn, 0.05);
  });
}


