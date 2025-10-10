import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/intelligent_cache.dart';
import 'package:mytrademate/ai/prediction_cache.dart';

void main() {
  group('IntelligentCacheManager.ttlForVol', () {
    test('high volatility >5% => 10s', () {
      final m = IntelligentCacheManagerFake();
      expect(m.ttlForVol(0.06).inSeconds, 10);
      expect(m.ttlForVol(0.20).inSeconds, 10);
    });
    test('medium volatility 2-5% => 20s', () {
      final m = IntelligentCacheManagerFake();
      expect(m.ttlForVol(0.02).inSeconds, 20);
      expect(m.ttlForVol(0.05).inSeconds, 20);
      expect(m.ttlForVol(0.035).inSeconds, 20);
    });
    test('low volatility <2% => 30s', () {
      final m = IntelligentCacheManagerFake();
      expect(m.ttlForVol(0.0).inSeconds, 30);
      expect(m.ttlForVol(0.019).inSeconds, 30);
    });
  });
}

/// Minimal harness to access ttlForVol without wiring PredictionCache
class IntelligentCacheManagerFake extends IntelligentCacheManager {
  IntelligentCacheManagerFake() : super(PredictionCache());
}


