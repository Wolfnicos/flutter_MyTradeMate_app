import 'dart:math' as math;
import 'dart:typed_data';

/// Returns similarity between two charts in [0,1], where 1 means identical.
/// Assumes both images are same length (e.g., same WxH and RGB layout).
double calculateImageSimilarity(Uint8List a, Uint8List b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a.length != b.length) return 0.0;

  // Mean Squared Error normalized to 0..1, then convert to similarity = 1 - MSE
  // Uses full precision; for speed, you can sample with a stride.
  double mse = 0.0;
  for (int i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).toDouble();
    mse += (d * d);
  }
  mse /= a.length; // average per channel byte
  // Normalize by max variance (255^2)
  final normMse = mse / (255.0 * 255.0);
  final sim = 1.0 - normMse;
  return sim.clamp(0.0, 1.0);
}

/// Logs similarity of consecutive charts to check diversity.
void analyzeChartDiversity(List<Uint8List> charts) {
  for (int i = 0; i < charts.length - 1; i++) {
    final s = calculateImageSimilarity(charts[i], charts[i + 1]);
    // ignore: avoid_print
    print('[Chart-Analysis] Similarity between chart $i and ${i + 1}: ${s.toStringAsFixed(4)}');
  }
}


