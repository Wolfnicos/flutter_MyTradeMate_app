@TestOn('!mac-os && !windows && !linux')
@Tags(['needs-tflite'])

import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/predictor_tflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TFLite predictor loads and runs', () async {
    final pred = TFLitePredictor();
    // fereastră [64 x 9] dummy, ordinea feature-urilor = norm.json
    final window = List.generate(64, (_) => List.filled(9, 0.01));
    final out = await pred.predict('BTCUSDT', window, timeframe: '15m');
    expect(out, isNotNull);
    final p = out!;
    expect(p.pBuy + p.pHold + p.pSell, greaterThan(0.99));
  });
}
