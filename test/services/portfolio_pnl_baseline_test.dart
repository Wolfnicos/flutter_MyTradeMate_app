import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mytrademate/services/portfolio_pnl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first run sets baseline = today total; delta = 0', () async {
    SharedPreferences.setMockInitialValues({});
    final (delta, baseline) = await PnlBaselineStore.computeAndPersist(
      todaysTotal: 100.0,
      now: DateTime.utc(2025, 10, 1, 12),
    );
    expect(baseline, 100.0);
    expect(delta, 0.0);
  });

  test('next day rolls baseline and computes delta', () async {
    SharedPreferences.setMockInitialValues({});
    await PnlBaselineStore.computeAndPersist(
      todaysTotal: 200.0,
      now: DateTime.utc(2025, 10, 1, 12),
    );
    final (delta, baseline) = await PnlBaselineStore.computeAndPersist(
      todaysTotal: 250.0,
      now: DateTime.utc(2025, 10, 2, 9),
    );
    expect(baseline, 250.0); // baseline reset for new day
    expect(delta, 0.0);      // at start of day
  });
}


