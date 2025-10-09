import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/utils/throttler.dart';

void main() {
  test('Throttler suppresses rapid calls', () async {
    final t = Throttler(const Duration(milliseconds: 50));
    int count = 0;
    t.run(() => count++);
    t.run(() => count++);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    t.run(() => count++);
    expect(count, 2);
  });
}


