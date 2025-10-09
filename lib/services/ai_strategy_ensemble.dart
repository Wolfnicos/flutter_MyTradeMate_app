
/// Ensemble AI Strategy - Combină multiple strategi pentru predicții mai puternice
/// Folosește voting între 3 strategi: Trend Following, Mean Reversion, Momentum
class AIStrategyEnsemble {
  /// Strategy 1: Trend Following
  /// Identifică trendul dominant și urmărește mișcarea
  static String trendFollowing(
    double probUp,
    double currentPrice,
    double prevPrice,
    double vol,
  ) {
    final priceChange = (currentPrice - prevPrice) / prevPrice;
    final trend = priceChange > 0.01 ? 'UP' : (priceChange < -0.01 ? 'DOWN' : 'FLAT');
    
    if (trend == 'UP' && probUp >= 0.55) return 'BUY';
    if (trend == 'DOWN' && probUp <= 0.45) return 'SELL';
    return 'HOLD';
  }
  
  /// Strategy 2: Mean Reversion
  /// Caută oportunități când prețul se îndepărtează de mean
  static String meanReversion(
    double probUp,
    double currentPrice,
    double avgPrice, // SMA sau media din sequence
    double vol,
  ) {
    final deviation = (currentPrice - avgPrice) / avgPrice;
    
    // Dacă prețul e prea jos față de medie și probUp > 0.5 → BUY
    if (deviation < -0.03 && probUp > 0.50) return 'BUY';
    
    // Dacă prețul e prea sus față de medie și probUp < 0.5 → SELL
    if (deviation > 0.03 && probUp < 0.50) return 'SELL';
    
    return 'HOLD';
  }
  
  /// Strategy 3: Momentum
  /// Urmărește momentum-ul și volatilitatea
  static String momentum(
    double probUp,
    double nextReturn,
    double vol,
  ) {
    // Strong momentum cu probabilitate mare → BUY
    if (nextReturn > 0.02 && probUp >= 0.60) return 'BUY';
    
    // Negative momentum cu probabilitate mică → SELL
    if (nextReturn < -0.02 && probUp <= 0.40) return 'SELL';
    
    // High volatility → prudent (HOLD bias)
    if (vol > 0.15) return 'HOLD';
    
    return 'HOLD';
  }
  
  /// Ensemble Voting: Combină cele 3 strategi
  static String ensemble({
    required double probUp,
    required double currentPrice,
    required double prevPrice,
    required double avgPrice,
    required double nextReturn,
    required double vol,
  }) {
    final s1 = trendFollowing(probUp, currentPrice, prevPrice, vol);
    final s2 = meanReversion(probUp, currentPrice, avgPrice, vol);
    final s3 = momentum(probUp, nextReturn, vol);
    
    // Count votes
    int buyVotes = 0;
    int sellVotes = 0;
    int holdVotes = 0;
    
    for (final strategy in [s1, s2, s3]) {
      if (strategy == 'BUY') {
        buyVotes++;
      } else if (strategy == 'SELL') sellVotes++;
      else holdVotes++;
    }
    
    // Majority wins (2 or 3 votes)
    if (buyVotes >= 2) return 'BUY';
    if (sellVotes >= 2) return 'SELL';
    
    // Default to HOLD (safe!)
    return 'HOLD';
  }
  
  /// Enhanced confidence based on strategy agreement
  static double ensembleConfidence({
    required double baseConfidence,
    required String s1,
    required String s2,
    required String s3,
    required String finalAction,
  }) {
    // Count how many strategies agree with final action
    int agreement = 0;
    if (s1 == finalAction) agreement++;
    if (s2 == finalAction) agreement++;
    if (s3 == finalAction) agreement++;
    
    // Adjust confidence based on agreement
    double multiplier = 1.0;
    if (agreement == 3) {
      multiplier = 1.15; // All agree → boost 15%
    } else if (agreement == 2) {
      multiplier = 1.0; // Majority → keep
    } else {
      multiplier = 0.70; // Weak agreement → reduce 30%
    }
    
    return (baseConfidence * multiplier).clamp(20.0, 95.0);
  }
}


