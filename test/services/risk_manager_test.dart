import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/risk_manager.dart';

void main() {
  test('allows trade when within limits', () {
    const rm = RiskManager(RiskConfig(
      maxPositionQuoteUsdt: 500.0,
      dailyLossCapUsdt: 100.0,
      maxConcurrentPositions: 3,
      cooldownAfterLoss: Duration(minutes: 30),
    ));
    final v = rm.check(RiskInput(
      symbol: 'BTCUSDT',
      desiredQuoteUsdt: 100.0,
      openPositionsCount: 1,
      currentDailyDeltaUsdt: 50.0,
      now: DateTime.fromMillisecondsSinceEpoch(0),
      lastLossAt: null,
    ));
    expect(v, isNull);
  });

  test('blocks when max position exceeded', () {
    const rm = RiskManager(RiskConfig(maxPositionQuoteUsdt: 100.0));
    final v = rm.check(RiskInput(
      symbol: 'BTCUSDT',
      desiredQuoteUsdt: 150.0,
      openPositionsCount: 0,
      currentDailyDeltaUsdt: 0.0,
      now: DateTime.fromMillisecondsSinceEpoch(0),
    ));
    expect(v, isNotNull);
    expect(v!.code, 'MAX_POSITION');
  });

  test('blocks when daily loss cap reached', () {
    const rm = RiskManager(RiskConfig(dailyLossCapUsdt: 100.0));
    final v = rm.check(RiskInput(
      symbol: 'BTCUSDT',
      desiredQuoteUsdt: 10.0,
      openPositionsCount: 0,
      currentDailyDeltaUsdt: -100.0,
      now: DateTime.fromMillisecondsSinceEpoch(0),
    ));
    expect(v, isNotNull);
    expect(v!.code, 'DAILY_LOSS_CAP');
  });

  test('blocks when max concurrency reached', () {
    const rm = RiskManager(RiskConfig(maxConcurrentPositions: 2));
    final v = rm.check(RiskInput(
      symbol: 'ETHUSDT',
      desiredQuoteUsdt: 10.0,
      openPositionsCount: 2,
      currentDailyDeltaUsdt: 0.0,
      now: DateTime.fromMillisecondsSinceEpoch(0),
    ));
    expect(v, isNotNull);
    expect(v!.code, 'MAX_CONCURRENCY');
  });

  test('blocks when cooling down after loss', () {
    final now = DateTime.fromMillisecondsSinceEpoch(60 * 1000);
    const rm =
        RiskManager(RiskConfig(cooldownAfterLoss: Duration(minutes: 10)));
    final v = rm.check(RiskInput(
      symbol: 'BTCUSDT',
      desiredQuoteUsdt: 10.0,
      openPositionsCount: 0,
      currentDailyDeltaUsdt: 0.0,
      now: now,
      lastLossAt: now.subtract(const Duration(minutes: 5)),
    ));
    expect(v, isNotNull);
    expect(v!.code, 'COOLDOWN');
  });

  test('blocks when circuit breaker triggered', () {
    const rm = RiskManager(RiskConfig(circuitBreakerOnUnhealthy: true));
    final v = rm.check(RiskInput(
      symbol: 'BTCUSDT',
      desiredQuoteUsdt: 10.0,
      openPositionsCount: 0,
      currentDailyDeltaUsdt: 0.0,
      now: DateTime.fromMillisecondsSinceEpoch(0),
      systemHealthy: false,
    ));
    expect(v, isNotNull);
    expect(v!.code, 'CIRCUIT_BREAKER');
  });
}
