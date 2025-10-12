class EnsembleResult {
  final List<double> probs; // [pBuy, pHold, pSell]
  final double expReturn; // expected return (fraction per period)
  final double annVol; // annualized volatility (fraction)
  final double confidence; // [0..1]
  final Map<String, dynamic> debug; // optional per-model details

  const EnsembleResult({
    required this.probs,
    required this.expReturn,
    required this.annVol,
    required this.confidence,
    this.debug = const {},
  });
}
