import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mytrademate/ai/ai_locator.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AILocator.I.init();
  });

  test('Direction softmax is not uniform on validation sample', () async {
    final p = await AILocator.I.getPrediction('BTCUSDT');
    expect(p, isNotNull);
    final probs = [p!.pSell, p.pHold, p.pBuy];
    final entropy = -probs.map((x) {
      final v = x <= 0 ? 1e-12 : x;
      return v * math.log(v);
    }).reduce((a, b) => a + b);
    // uniform(3) entropy ~= 1.099. We want a minimal distinction
    expect(entropy, lessThan(1.05));
  });
}
