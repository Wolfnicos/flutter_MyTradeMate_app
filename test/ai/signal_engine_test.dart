import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/ai/entities.dart';
import 'package:mytrademate/ai/signal_engine.dart';
import 'package:mytrademate/ai/models/direction_model.dart';

void main() {
  group('SignalEngine Tests', () {
    test('Prediction has valid confidence bounded 0-1', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      
      final data = List.generate(
        60,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(minutes: 60 - i)),
          open: 100.0 + i,
          high: 101.0 + i,
          low: 99.0 + i,
          close: 100.0 + i,
          volume: 1000.0 + i,
        ),
      );
      
      final pred = await engine.predict('BTCUSDT', data);
      
      expect(pred, isNotNull);
      expect(pred!.confidence(), inInclusiveRange(0.0, 1.0));
      expect(pred.pBuy + pred.pHold + pred.pSell, closeTo(1.0, 0.01));
    });

    test('Action is one of BUY/HOLD/SELL', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      
      final data = List.generate(
        60,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(minutes: 60 - i)),
          open: 100.0 + i,
          high: 101.0 + i,
          low: 99.0 + i,
          close: 100.0 + i,
          volume: 1000.0 + i,
        ),
      );
      
      final pred = await engine.predict('BTCUSDT', data);
      
      expect(pred, isNotNull);
      final decision = engine.decide(pred!);
      
      expect(['BUY', 'HOLD', 'SELL'], contains(decision));
    });

    test('Target price is realistic (within ±20% of current)', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      
      final data = List.generate(
        60,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(minutes: 60 - i)),
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 1000.0,
        ),
      );
      
      final pred = await engine.predict('BTCUSDT', data);
      
      expect(pred, isNotNull);
      final lastClose = data.last.close;
      final target = pred!.targetPrice(lastClose);
      
      // Target should be within ±20% (realistic daily move)
      expect(target, greaterThan(lastClose * 0.80));
      expect(target, lessThan(lastClose * 1.20));
    });

    test('Expected return is bounded (±5%)', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      
      final data = List.generate(
        60,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(minutes: 60 - i)),
          open: 100.0 + i * 0.5,
          high: 101.0 + i * 0.5,
          low: 99.0 + i * 0.5,
          close: 100.0 + i * 0.5,
          volume: 1000.0,
        ),
      );
      
      final pred = await engine.predict('BTCUSDT', data);
      
      expect(pred, isNotNull);
      expect(pred!.expReturn, greaterThanOrEqualTo(-0.05));
      expect(pred.expReturn, lessThanOrEqualTo(0.05));
    });

    test('Volatility is positive and realistic (<300%)', () async {
      final engine = SignalEngine(dirModel: DirectionModel());
      
      final data = List.generate(
        60,
        (i) => Candle(
          time: DateTime.now().subtract(Duration(minutes: 60 - i)),
          open: 100.0,
          high: 105.0,
          low: 95.0,
          close: 100.0 + (i % 2 == 0 ? 2.0 : -2.0), // Volatile
          volume: 1000.0,
        ),
      );
      
      final pred = await engine.predict('BTCUSDT', data);
      
      expect(pred, isNotNull);
      expect(pred!.annVol, greaterThan(0.0));
      expect(pred.annVol, lessThan(3.0)); // <300% annual
    });
  });
}

