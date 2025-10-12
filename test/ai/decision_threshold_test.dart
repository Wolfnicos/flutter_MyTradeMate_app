import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/entities.dart' as ai;
import '../fakes/fake_engine.dart';

void main() {
  test('probs [.33,.34,.33] ⇒ HOLD by decision', () async {
    AILocator.I.overrideEngineForTests(FakeEngine());

    final p = ai.Prediction(
      symbol: 'X',
      asOf: DateTime.utc(2025, 1, 1),
      pBuy: 0.33,
      pHold: 0.34,
      pSell: 0.33,
      expReturn: 0.0005,
      annVol: 0.10,
      relVolume: 1.0,
    );

    final action = AILocator.I.decide(p);
    expect(action, 'HOLD');
  });
}
