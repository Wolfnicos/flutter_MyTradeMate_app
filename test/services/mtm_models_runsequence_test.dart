import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _Stub extends MtmModels {
  @override
  double predictDirection(Object _) => 0.6;
  @override
  double predictReturn(Object _) => 0.015;
  @override
  double predictVolatility(Object _) => 0.08;
}

void main() {
  test('runSequence returns combined outputs', () async {
    final m = _Stub();
    final out = await m.runSequence(List.generate(64, (_) => [0.0, 0.0, 0.0]));
    expect(out.probUp, 0.6);
    expect(out.nextReturn, 0.015);
    expect(out.volatility, 0.08);
  });
}


