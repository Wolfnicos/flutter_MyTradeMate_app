import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _AllNull extends MtmModels {
  @override
  double predictDirection(Object _) => throw Exception('no model');
  @override
  double predictReturn(Object _) => throw Exception('no model');
  @override
  double predictVolatility(Object _) => throw Exception('no model');
}

class _AllVals extends MtmModels {
  @override
  double predictDirection(Object _) => 0.6;
  @override
  double predictReturn(Object _) => 0.02;
  @override
  double predictVolatility(Object _) => 0.1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runSequence handles nulls (defaults used upstream)', () async {
    final m = _AllNull()..markLoadedForTest(const ['a', 'b', 'c']);
    final seq = List.generate(64, (_) => <double>[0, 0, 0]);
    final out = await m.predictAllFromSequence(seq);
    expect(out.probUp, isNull);
    expect(out.nextReturn, isNull);
    expect(out.volatility, isNull);
  });

  test('runSequence aggregates provided values', () async {
    final m = _AllVals()..markLoadedForTest(const ['a', 'b', 'c']);
    final seq = List.generate(64, (_) => <double>[0, 0, 0]);
    final out = await m.predictAllFromSequence(seq);
    expect(out.probUp, 0.6);
    expect(out.nextReturn, 0.02);
    expect(out.volatility, 0.1);
  });
}
