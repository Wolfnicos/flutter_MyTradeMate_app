import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/utils/debouncer.dart';

void main() {
  test('Debouncer calls only the last action', () async {
    var calls = 0;
    final d = Debouncer(delay: const Duration(milliseconds: 50));
    d(() => calls++);
    d(() => calls++);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(calls, 1);
    d.dispose();
  });
}

