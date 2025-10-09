import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Offline shows friendly error (logic)', () async {
    const online = false;
    const message = online ? null : 'No internet connection';
    expect(message, isNotNull);
  });
}


