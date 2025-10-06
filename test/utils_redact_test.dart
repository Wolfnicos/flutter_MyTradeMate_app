import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/utils/redact.dart';

void main() {
  test('redact handles null/empty and short strings', () {
    expect(redact(null), '');
    expect(redact(''), '');
    expect(redact('abc'), '••••');
  });

  test('redact masks middle and keeps head/tail', () {
    expect(redact('ABCDEFGHIJKLMNOP', head: 4, tail: 3), 'ABCD•••NOP');
    expect(redact('1234567890'), '1234•••90');
  });
}
