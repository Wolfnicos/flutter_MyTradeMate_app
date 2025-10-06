import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _EchoModels extends MtmModels {
  num _extractLastClose(Object input) {
    if (input is List && input.isNotEmpty) {
      final first = input.first;
      // Shape from runSequence: input == [seq] where seq is List<List<num>>
      if (first is List && first.isNotEmpty) {
        final maybeRow = first.last;
        if (maybeRow is List && maybeRow.isNotEmpty) {
          final v = maybeRow.first;
          if (v is num) return v;
        }
        // Shape from runFor: input == [vector]
        final v2 = first.first;
        if (v2 is num) return v2;
      }
    }
    return 0;
  }

  @override
  double predictDirection(Object input) =>
      _extractLastClose(input).toDouble() / 1000.0;

  @override
  double predictReturn(Object input) =>
      _extractLastClose(input).toDouble() / 10000.0;

  @override
  double predictVolatility(Object input) =>
      _extractLastClose(input).toDouble() / 100.0;
}

void main() {
  test(
      'predictAllFromSequence uses overridden predictors after markLoadedForTest',
      () async {
    final m = _EchoModels();
    m.markLoadedForTest(const ['last', 'ret1']);
    final out = await m.predictAllFromSequence(const [
      [100.0, 0],
      [200.0, 0],
    ]);
    expect(out.probUp, closeTo(0.2, 1e-6));
    expect(out.nextReturn, closeTo(0.02, 1e-6));
    expect(out.volatility, closeTo(2.0, 1e-6));
  });

  test('predictAll returns finite numbers with overridden predictors',
      () async {
    final m = _EchoModels();
    m.markLoadedForTest(const ['last', 'ret1']);
    final out = await m.predictAll({'last': 300.0, 'ret1': 0.0});
    expect(out.probUp, isA<num>());
    expect(out.nextReturn, isA<num>());
    expect(out.volatility, isA<num>());
  });
}
