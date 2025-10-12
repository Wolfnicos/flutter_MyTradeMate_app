class ExplainData {
  final String symbol;
  final DateTime asOf;
  final double pBuy;
  final double expReturn;
  final double annVol;
  final List<List<double>> features;
  final String modelRev;

  const ExplainData({
    required this.symbol,
    required this.asOf,
    required this.pBuy,
    required this.expReturn,
    required this.annVol,
    required this.features,
    required this.modelRev,
  });

  double confidence() => pBuy >= 0.5 ? pBuy : (1 - pBuy);

  // Backward-compat getters (used by existing UI/tests)
  double get probUp => pBuy;
  double get nextReturn => expReturn;
  double get volatility => annVol;
  String get volatilityLabel {
    final a = annVol.abs();
    if (a >= 0.15) return 'HIGH';
    if (a >= 0.05) return 'MEDIUM';
    return 'LOW';
  }
}

ExplainData mapToExplain(
  String symbol,
  List<List<double>> seq, {
  required DateTime asOf,
  required double pBuy,
  required double expReturn,
  required double annVol,
  String modelRev = 'r-test',
}) {
  return ExplainData(
    symbol: symbol,
    asOf: asOf,
    pBuy: pBuy,
    expReturn: expReturn,
    annVol: annVol,
    features: seq,
    modelRev: modelRev,
  );
}
