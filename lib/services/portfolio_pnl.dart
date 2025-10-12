import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

class PnlBaselineStore {
  static const _kTotalUsdt = 'portfolio_yesterday_total_usdt';
  static const _kRefDate = 'portfolio_last_ref_yyyymmdd';

  @visibleForTesting
  static String yyyymmdd(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Returns (delta, storedBaseline) after ensuring baseline for `today` is set.
  static Future<(double delta, double baseline)> computeAndPersist({
    required double todaysTotal,
    DateTime? now,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final now0 = now ?? DateTime.now().toUtc();
    final todayKey = yyyymmdd(now0);
    final lastRef = sp.getString(_kRefDate);
    final baseline = sp.getDouble(_kTotalUsdt);

    double usedBaseline;
    if (baseline == null || lastRef != todayKey) {
      await sp.setDouble(_kTotalUsdt, todaysTotal);
      await sp.setString(_kRefDate, todayKey);
      usedBaseline = todaysTotal;
    } else {
      usedBaseline = baseline;
    }
    final delta = todaysTotal - usedBaseline;
    return (delta, usedBaseline);
  }
}
