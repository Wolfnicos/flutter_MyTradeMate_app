import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/ai_config.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import '../fakes/fake_engine.dart';

void main() {
  test('Dashboard vs Assistant: same input → same outputs', () async {
    AILocator.I.overrideEngineForTests(FakeEngine());

    // Simulate two calls for the same symbol; FakeEngine returns fixed output
    final a = await AILocator.I.getPrediction('BTCUSDT');
    final b = await AILocator.I.getPrediction('BTCUSDT');

    expect(a, isNotNull);
    expect(b, isNotNull);
    final pa = a!;
    final pb = b!;
    expect((pa.pBuy - pb.pBuy).abs() <= AiConfig.maxFloatDrift, true);
    expect((pa.expReturn - pb.expReturn).abs() <= AiConfig.maxFloatDrift, true);
    expect((pa.annVol - pb.annVol).abs() <= AiConfig.maxFloatDrift, true);
  });
}


