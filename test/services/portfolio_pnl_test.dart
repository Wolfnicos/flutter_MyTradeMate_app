import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/services/portfolio_pnl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('computeAndPersist sets baseline for first run and delta=0', () async {
    SharedPreferences.setMockInitialValues({});
    final (delta, base) = await PnlBaselineStore.computeAndPersist(
      todaysTotal: 1234.56,
      now: DateTime.utc(2025, 1, 2),
    );
    expect(base, closeTo(1234.56, 1e-9));
    expect(delta, 0);
  });

  test('computeAndPersist returns delta against yesterday baseline', () async {
    SharedPreferences.setMockInitialValues({});
    // Day 1: set baseline
    await PnlBaselineStore.computeAndPersist(
      todaysTotal: 1000.0,
      now: DateTime.utc(2025, 1, 2),
    );
    // Same day: delta reflects change vs baseline (1000)
    final (delta1, base1) = await PnlBaselineStore.computeAndPersist(
      todaysTotal: 1100.0,
      now: DateTime.utc(2025, 1, 2),
    );
    expect(base1, 1000.0);
    expect(delta1, 100.0);
    // Next day: baseline resets to new total
    final (delta2, base2) = await PnlBaselineStore.computeAndPersist(
      todaysTotal: 1200.0,
      now: DateTime.utc(2025, 1, 3),
    );
    expect(base2, 1200.0);
    expect(delta2, 0.0);
  });
}


