import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  test('mapToExplain carries raw outputs and features', () {
    const r = AIPrediction(
      action: 'BUY',
      confidence: 56.0,
      targetPrice: 101.0,
      volatility: 'MEDIUM',
      probUp: 0.56,
      nextReturn: 0.01,
      volatilityValue: 0.05,
    );
    final seq = List.generate(64, (_) => [0.0, 1.0, 2.0]);
    final ex = mapToExplain('BTCUSDT', seq, r);
    expect(ex.symbol, 'BTCUSDT');
    expect(ex.probUp, closeTo(0.56, 1e-9));
    expect(ex.nextReturn, closeTo(0.01, 1e-9));
    expect(ex.volatility, closeTo(0.05, 1e-9));
    expect(ex.volatilityLabel, 'MEDIUM');
    expect(ex.features.length, 64);
  });
}

