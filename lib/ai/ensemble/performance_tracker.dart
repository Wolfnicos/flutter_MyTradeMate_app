/// Tracks simple correctness per model to drive adaptive weights.
class PerformanceTracker {
  int dirTotal = 0;
  int dirHits = 0;
  int retTotal = 0;
  int retHits = 0;
  int volTotal = 0;
  int volHits = 0;
  int techTotal = 0;
  int techHits = 0;

  void recordDirection({required String model, required bool hit}) {
    switch (model) {
      case 'dir':
        dirTotal++;
        if (hit) dirHits++;
        break;
      case 'tech':
        techTotal++;
        if (hit) techHits++;
        break;
    }
  }

  void recordReturn({required bool hit}) {
    retTotal++;
    if (hit) retHits++;
  }

  void recordVol({required bool hit}) {
    volTotal++;
    if (hit) volHits++;
  }

  double get accDir => dirTotal == 0 ? 0.5 : dirHits / dirTotal;
  double get accRet => retTotal == 0 ? 0.5 : retHits / retTotal;
  double get accVol => volTotal == 0 ? 0.5 : volHits / volTotal;
  double get accTech => techTotal == 0 ? 0.5 : techHits / techTotal;
}
