// Scaffolding for Confirm + Undo UI flow tests (skipped until feature lands)
// Intention:
// 1) Opening a trade triggers confirm sheet with order summary and confirm/undo.
// 2) Tap confirm → broker receives order.
// 3) Tap undo on snackbar (within 5–7s) → broker.cancel(orderId), order → CANCELED.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Confirm sheet + Undo snackbar flow (scaffold)', (t) async {
    // This file is intentionally skipped from discovery (in test/_skipped with .SKIP.dart).
    // When implementing the feature, move to test/ui/ and wire a real widget harness.
    expect(true, isTrue);
  });
}
