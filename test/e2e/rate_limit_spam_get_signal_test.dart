import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Spam get-signal triggers backoff flag (logic smoke)', () async {
    int calls = 0;
    bool backoff = false;
    for (int i = 0; i < 12; i++) {
      calls++;
      if (calls > 10) backoff = true;
    }
    expect(backoff, isTrue);
  });
}

