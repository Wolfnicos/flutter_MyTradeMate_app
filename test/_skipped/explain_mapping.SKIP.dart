import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:test/test.dart' as test show Skip;
@test.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')

void main() {
  test('mapToExplain carries AI result and features', () {
    final seq = List.generate(64, (_) => <double>[1, 2, 3]);
    const r = AIPrediction(
      action: 'BUY',
      confidence: 66.0,
      targetPrice: 1234.0,
      volatility: 'HIGH',
      probUp: 0.66,
      nextReturn: 0.02,
      volatilityValue: 0.12,
    );
    final d = mapToExplain('BTCUSDT', seq, r);
    expect(d.symbol, 'BTCUSDT');
    expect(d.probUp, closeTo(0.66, 1e-9));
    expect(d.volatilityLabel, 'HIGH');
    expect(d.features.length, 64);
  });
}


