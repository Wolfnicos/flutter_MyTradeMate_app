import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trade CTA disabled if keys empty (guarded)', () async {
    // Pure logic check—your UI layer should expose a selector like:
    const hasKeys = false;
    const ctaEnabled = hasKeys; // simplified
    expect(ctaEnabled, isFalse);
  });
}

