import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:test/test.dart' as test show Skip;
@test.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')

void main() {
  test(
      'featuresFromTickerForTest returns a 64xN finite sequence and is stable for same input',
      () {
    final seq1 = featuresFromTickerForTest(1234.5);
    final seq2 = featuresFromTickerForTest(1234.5);

    expect(seq1.length, 64);
    expect(seq2.length, 64);

    for (final row in seq1) {
      expect(row.isNotEmpty, true);
      for (final v in row) {
        expect(v.isFinite, true);
      }
    }

    for (var i = 0; i < 64; i++) {
      expect(seq1[i].length, seq2[i].length);
      for (var j = 0; j < seq1[i].length; j++) {
        expect(seq1[i][j], closeTo(seq2[i][j], 1e-12));
      }
    }
  });
}


