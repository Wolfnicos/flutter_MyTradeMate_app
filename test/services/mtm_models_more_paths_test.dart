import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _Echo extends MtmModels {
  num _extractLast(Object input) {
    if (input is List && input.isNotEmpty) {
      final first = input.first;
      if (first is List && first.isNotEmpty) {
        final row = first.last;
        if (row is List && row.isNotEmpty) {
          final v = row.first;
          if (v is num) return v;
        }
      }
    }
    return 0;
  }

  @override
  double predictDirection(Object input) => _extractLast(input).toDouble() / 100.0;
  @override
  double predictReturn(Object input) => _extractLast(input).toDouble() / 200.0;
  @override
  double predictVolatility(Object input) => _extractLast(input).toDouble() / 50.0;
}

void main() {
  test('markLoadedForTest allows predictions; different sequences differ', () async {
    final m = _Echo()..markLoadedForTest(const ['last']);
    final a = await m.predictAllFromSequence(const [
      [50.0],
      [50.0],
    ]);
    final b = await m.predictAllFromSequence(const [
      [60.0],
      [60.0],
    ]);
    expect(a.probUp, isNotNull);
    expect(b.probUp, isNotNull);
    expect(b.probUp, isNot(equals(a.probUp)));
  });
}


