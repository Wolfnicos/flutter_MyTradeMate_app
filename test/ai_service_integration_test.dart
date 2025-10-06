import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AIService fake mode produces deterministic BUY', () async {
    // In CI we cannot set dart-define for tests, so we directly expect real call may fail.
    // Instead we validate that deterministic path returns expected values when enabled.
    final ai = AIService(enableFake: true);
    final pred = await ai.getPrediction('BTCUSDT');
    expect(pred.action, 'BUY');
    expect(pred.confidence, 60.0);
  });
}
