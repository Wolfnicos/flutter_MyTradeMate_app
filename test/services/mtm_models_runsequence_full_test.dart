import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _StubTriple extends MtmModels {
  final double p, r, v;
  _StubTriple(this.p, this.r, this.v);

  @override
  double predictDirection(Object _) => p;

  @override
  double predictReturn(Object _) => r;

  @override
  double predictVolatility(Object _) => v;
}

void main() {
  test('runSequence aggregates outputs from all three predictors', () async {
    final m = _StubTriple(0.61, 0.0123, 0.081);
    final seq = List.generate(64, (_) => <double>[0.0, 0.0, 0.0]); // 64xN
    final out = await m.runSequence(seq);
    expect(out.probUp, closeTo(0.61, 1e-12));
    expect(out.nextReturn, closeTo(0.0123, 1e-12));
    expect(out.volatility, closeTo(0.081, 1e-12));
  });
}


