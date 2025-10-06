import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/signal_policy.dart';

class _Clock {
  DateTime t;
  _Clock(this.t);
  DateTime now() => t;
  void fwd(Duration d) {
    t = t.add(d);
  }
}

void main() {
  test('Edge thresholds and hysteresis prevent flapping', () {
    final clock = _Clock(DateTime.utc(2024, 1, 1, 0, 0, 0));
    final pol = SignalPolicy(
      cfg: const SignalPolicyConfig(
        buyThreshold: 0.55,
        sellThreshold: 0.45,
        hysteresisBand: 0.02,
        cooldown: Duration.zero,
      ),
      now: clock.now,
      userConsent: () => true,
      quoteSizer: (_) => 25.0,
    );
    // just above buy threshold -> BUY
    final i1 = pol.evaluate(symbol: 'BTCUSDT', probUp: 0.56, confidence: 80);
    expect(i1?.side, 'BUY');
    // tiny dip inside hysteresis should HOLD (no SELL yet)
    final i2 = pol.evaluate(symbol: 'BTCUSDT', probUp: 0.46, confidence: 80);
    expect(i2, isNull);
    // cross below sell with band -> SELL allowed
    final i3 = pol.evaluate(symbol: 'BTCUSDT', probUp: 0.43, confidence: 80);
    expect(i3?.side, 'SELL');
  });

  test('Cooldown and max trades/day prevent overtrading', () {
    final clock = _Clock(DateTime.utc(2024, 1, 1, 0, 0, 0));
    final pol = SignalPolicy(
      cfg: const SignalPolicyConfig(
          cooldown: Duration(minutes: 10), maxTradesPerDay: 2),
      now: clock.now,
      userConsent: () => true,
      quoteSizer: (_) => 50.0,
    );
    // First BUY
    final a = pol.evaluate(symbol: 'ETHUSDT', probUp: 0.7, confidence: 90);
    expect(a?.side, 'BUY');
    // Within cooldown -> none
    final b = pol.evaluate(symbol: 'ETHUSDT', probUp: 0.7, confidence: 90);
    expect(b, isNull);
    // Advance past cooldown -> second BUY
    clock.fwd(const Duration(minutes: 11));
    final c = pol.evaluate(symbol: 'ETHUSDT', probUp: 0.7, confidence: 90);
    expect(c?.side, 'BUY');
    // Max trades/day reached -> block further
    clock.fwd(const Duration(minutes: 11));
    final d = pol.evaluate(symbol: 'ETHUSDT', probUp: 0.7, confidence: 90);
    expect(d, isNull);
    // Next day resets counter
    clock.fwd(const Duration(hours: 25));
    final e = pol.evaluate(symbol: 'ETHUSDT', probUp: 0.7, confidence: 90);
    expect(e?.side, 'BUY');
  });

  test('No user consent -> no intents', () {
    final pol = SignalPolicy(userConsent: () => false);
    final i = pol.evaluate(symbol: 'BTCUSDT', probUp: 0.9, confidence: 99);
    expect(i, isNull);
  });

  test('Min confidence gate blocks low-quality signals', () {
    final pol = SignalPolicy(
      cfg: const SignalPolicyConfig(minConfidence: 75),
      userConsent: () => true,
    );
    final i = pol.evaluate(symbol: 'BTCUSDT', probUp: 0.9, confidence: 60);
    expect(i, isNull);
  });
}
