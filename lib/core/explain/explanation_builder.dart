enum Direction { up, down, flat }

enum VolLevel { low, moderate, high }

class ExplanationInput {
  final Direction direction;
  final VolLevel volLevel;
  final double? confidence; // 0..1, poate fi null
  final List<String>
      topFactors; // ex: ["momentum_5m", "rv_30m", "volume_spike"]
  final bool dataGaps;
  final Duration lastTickAge; // cât de vechi e ultimul tick
  final bool isPaperMode;

  ExplanationInput({
    required this.direction,
    required this.volLevel,
    required this.confidence,
    required this.topFactors,
    required this.dataGaps,
    required this.lastTickAge,
    required this.isPaperMode,
  });
}

class ExplanationOutput {
  final String headline; // fraza principală
  final String details; // motivarea scurtă
  final String advisory; // “guidance, not advice”
  final String? uncertainty; // optional
  final String? dataGap; // optional

  const ExplanationOutput({
    required this.headline,
    required this.details,
    required this.advisory,
    this.uncertainty,
    this.dataGap,
  });
}

class ExplanationBuilder {
  // Praguri recomandate; ajustează din configurare dacă vrei.
  static const Duration staleAfter = Duration(seconds: 5);

  static String _dirWord(Direction d) => switch (d) {
        Direction.up => '↑ tendency',
        Direction.down => '↓ tendency',
        Direction.flat => 'sideways tendency',
      };

  static String _volWord(VolLevel v) => switch (v) {
        VolLevel.low => 'lower volatility',
        VolLevel.moderate => 'moderate volatility',
        VolLevel.high => 'higher volatility',
      };

  static String _confBucket(double c) {
    if (c >= 0.75) return 'higher confidence';
    if (c >= 0.5) return 'moderate confidence';
    return 'lower confidence';
  }

  static ExplanationOutput build(ExplanationInput i) {
    final c = (i.confidence ?? double.nan);
    final hasValidC = c.isFinite && !c.isNaN && c >= 0 && c <= 1;
    final confPct =
        hasValidC ? (c * 100).clamp(0, 100).toStringAsFixed(0) : '—';

    // Headline (fallback dacă lipsesc datele)
    final headline = hasValidC
        ? 'We estimate ${_dirWord(i.direction)} with ${_volWord(i.volLevel)} next period. Confidence $confPct%.'
        : 'We can’t reliably estimate direction/volatility right now (insufficient evidence).';

    // Detalii: folosește până la 3 factori
    final top = i.topFactors.take(3).toList();
    final factorCopy = top.isEmpty
        ? 'based on recent price dynamics and realized-volatility estimates.'
        : "based on signals like ${top.join(', ')}.";

    final details = hasValidC
        ? 'This is a probabilistic forecast $factorCopy'
        : 'Waiting for more data to reach minimum evidence thresholds.';

    // Advisory “guidance, not advice” + paper badge
    final advisory = i.isPaperMode
        ? 'Paper/Testnet only. Treat as guidance, not financial advice.'
        : 'Treat as guidance, not financial advice.';

    // Uncertainty: mapăm bucket textual (nu promite nimic)
    final uncertainty = hasValidC
        ? 'Uncertainty: ${_confBucket(c)}.'
        : 'Uncertainty elevated due to limited data.';

    // Data gaps: afișează dacă toggle-ul e ON sau dacă e staleness hard
    final isStale = i.lastTickAge > staleAfter;
    final dataGap = (i.dataGaps || isStale)
        ? "Data status: ${isStale ? "stale (${i.lastTickAge.inSeconds}s old)" : "gaps detected"}. Some inputs may be delayed or incomplete."
        : null;

    return ExplanationOutput(
      headline: headline,
      details: details,
      advisory: advisory,
      uncertainty: uncertainty,
      dataGap: dataGap,
    );
  }
}

