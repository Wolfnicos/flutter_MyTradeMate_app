import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/ensemble/ensemble_predictor.dart';
import 'package:mytrademate/ai/ensemble/model_weights.dart';
import 'package:mytrademate/ai/ensemble/performance_tracker.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/models/direction_model.dart';
import 'package:mytrademate/ai/models/return_model.dart';
import 'package:mytrademate/ai/models/volatility_model.dart';

class _DirStub extends DirectionModel {
  final List<double> p;
  _DirStub(this.p);
  @override
  Future<List<double>> predictProbs(List<Candle> candles) async => p;
}

class _RetStub extends ReturnModel {
  final double r;
  _RetStub(this.r);
  @override
  Future<double> predictReturn(List<Candle> window) async => r;
}

class _VolStub extends VolatilityModel {
  final double v;
  _VolStub(this.v);
  @override
  Future<double> predictVolatility(List<Candle> window) async => v;
}

List<Candle> _mkCandles(int n) {
  final out = <Candle>[];
  double price = 100;
  final now = DateTime.now();
  for (int i = 0; i < n; i++) {
    price *= 1.0005;
    out.add(Candle(
      time: now.add(Duration(minutes: i * 5)),
      open: price * 0.999,
      high: price * 1.001,
      low: price * 0.999,
      close: price,
      volume: 1000,
    ));
  }
  return out;
}

void main() {
  group('EnsemblePredictor', () {
    test('High confidence boost when models agree strongly', () async {
      final w = ModelWeights()
        ..dir = 0.35
        ..ret = 0.25
        ..vol = 0.20
        ..tech = 0.20;
      final ens = EnsemblePredictor(
        dirModel: _DirStub(const [0.7, 0.2, 0.1]),
        retModel: _RetStub(0.003),
        volModel: _VolStub(0.2),
        weights: w,
        tracker: PerformanceTracker(),
      );
      final models = [
        const SignalVote(direction: 'BUY', confidence: 0.85),
        const SignalVote(direction: 'BUY', confidence: 0.75),
        const SignalVote(direction: 'BUY', confidence: 0.70),
      ];
      const fallback = SignalVote(direction: 'BUY', confidence: 0.40);
      final combined = ens.combine(models, fallback);
      expect(combined.confidence, greaterThan(0.80));
      expect(combined.metadata['boost_applied'], isTrue);
    });

    test('No boost when models disagree', () async {
      final ens = EnsemblePredictor(
        dirModel: _DirStub(const [0.45, 0.10, 0.45]),
        retModel: _RetStub(0.0),
        volModel: _VolStub(0.2),
        weights: ModelWeights(),
        tracker: PerformanceTracker(),
      );
      final models = [
        const SignalVote(direction: 'BUY', confidence: 0.80),
        const SignalVote(direction: 'SELL', confidence: 0.75),
        const SignalVote(direction: 'HOLD', confidence: 0.60),
      ];
      const fallback = SignalVote(direction: 'HOLD', confidence: 0.40);
      final combined = ens.combine(models, fallback);
      expect(combined.confidence, lessThan(0.60));
      expect(combined.metadata['penalty_applied'], isTrue);
    });

    test('weighted averages for return and volatility', () async {
      final w = ModelWeights()
        ..dir = 0.35
        ..ret = 0.25
        ..vol = 0.20
        ..tech = 0.20;
      final ens = EnsemblePredictor(
        dirModel: _DirStub(const [0.6, 0.3, 0.1]),
        retModel: _RetStub(0.004),
        volModel: _VolStub(0.5),
        weights: w,
        tracker: PerformanceTracker(),
      );
      final window = _mkCandles(64);
      final res = await ens.predict(window);
      // expReturn near 0.004 scaled by weights normalization (denom ret+vol)
      expect(res.expReturn, greaterThan(0));
      expect(res.annVol, greaterThan(0));
    });
  });
}
