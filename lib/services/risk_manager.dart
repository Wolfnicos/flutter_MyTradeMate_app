class RiskConfig {
  final double? maxPositionQuoteUsdt; // max quote per single position
  final double? dailyLossCapUsdt; // e.g., -100.0 blocks further trades
  final int? maxConcurrentPositions;
  final Duration?
      cooldownAfterLoss; // block new trades within this window after a loss
  final bool circuitBreakerOnUnhealthy; // block when system/model unhealthy

  const RiskConfig({
    this.maxPositionQuoteUsdt,
    this.dailyLossCapUsdt,
    this.maxConcurrentPositions,
    this.cooldownAfterLoss,
    this.circuitBreakerOnUnhealthy = true,
  });
}

class RiskInput {
  final String symbol;
  final double desiredQuoteUsdt;
  final int openPositionsCount;
  final double currentDailyDeltaUsdt; // today PnL delta vs baseline
  final DateTime? lastLossAt;
  final DateTime now;
  final bool systemHealthy; // connectivity, data feed
  final bool modelHealthy; // inference/model

  const RiskInput({
    required this.symbol,
    required this.desiredQuoteUsdt,
    required this.openPositionsCount,
    required this.currentDailyDeltaUsdt,
    required this.now,
    this.lastLossAt,
    this.systemHealthy = true,
    this.modelHealthy = true,
  });
}

class RiskViolation implements Exception {
  final String
      code; // e.g., MAX_POSITION, DAILY_LOSS_CAP, MAX_CONCURRENCY, COOLDOWN, CIRCUIT_BREAKER
  final String message;
  RiskViolation(this.code, this.message);
  @override
  String toString() => 'RiskViolation($code): $message';
}

class RiskManager {
  final RiskConfig cfg;
  const RiskManager(this.cfg);

  RiskViolation? check(RiskInput i) {
    // Circuit breaker: system/model unhealthy
    if (cfg.circuitBreakerOnUnhealthy &&
        (!i.systemHealthy || !i.modelHealthy)) {
      return RiskViolation(
        'CIRCUIT_BREAKER',
        'Trading paused due to system/model health. Please retry later.',
      );
    }

    // Max position size
    if (cfg.maxPositionQuoteUsdt != null &&
        i.desiredQuoteUsdt > cfg.maxPositionQuoteUsdt!) {
      return RiskViolation(
        'MAX_POSITION',
        'Order exceeds max position size (${cfg.maxPositionQuoteUsdt!.toStringAsFixed(2)} USDT).',
      );
    }

    // Daily loss cap
    if (cfg.dailyLossCapUsdt != null &&
        i.currentDailyDeltaUsdt <= -cfg.dailyLossCapUsdt!.abs()) {
      return RiskViolation(
        'DAILY_LOSS_CAP',
        'Daily loss cap reached. Trading disabled for today.',
      );
    }

    // Max concurrent positions
    if (cfg.maxConcurrentPositions != null &&
        i.openPositionsCount >= cfg.maxConcurrentPositions!) {
      return RiskViolation(
        'MAX_CONCURRENCY',
        'Too many open positions (${i.openPositionsCount}). Close some before trading.',
      );
    }

    // Cooldown after loss
    if (cfg.cooldownAfterLoss != null && i.lastLossAt != null) {
      final sinceLoss = i.now.difference(i.lastLossAt!);
      if (sinceLoss < cfg.cooldownAfterLoss!) {
        final remain = cfg.cooldownAfterLoss! - sinceLoss;
        return RiskViolation(
          'COOLDOWN',
          'Cooling down after last loss. Retry in ${remain.inMinutes}m.',
        );
      }
    }

    return null; // allowed
  }
}

