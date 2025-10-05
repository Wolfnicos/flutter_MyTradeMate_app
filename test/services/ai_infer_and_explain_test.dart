import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/mtm_models.dart';

class BuyM extends MtmModels {
  @override
  double predictDirection(Object _) => 0.60;
  @override
  double predictReturn(Object _) => 0.02;
  @override
  double predictVolatility(Object _) => 0.10;
}

class HoldM extends MtmModels {
  @override
  double predictDirection(Object _) => 0.50;
  @override
  double predictReturn(Object _) => 0.00;
  @override
  double predictVolatility(Object _) => 0.04;
}

class SellM extends MtmModels {
  @override
  double predictDirection(Object _) => 0.40;
  @override
  double predictReturn(Object _) => -0.01;
  @override
  double predictVolatility(Object _) => 0.02;
}

List<List<double>> seq() => List.generate(64, (_) => <double>[1, 2, 3]);

void main() {
  test('BUY branch', () async {
    final inf = await inferAndExplainForTest(
      symbol: 'BTCUSDT',
      seq: seq(),
      last: 1000,
      models: BuyM(),
    );
    expect(inf.result.action, 'BUY');
    expect(inf.result.targetPrice, closeTo(1020.0, 1e-9));
    expect(inf.explain.features.length, 64);
  });

  test('HOLD branch', () async {
    final inf = await inferAndExplainForTest(
      symbol: 'BTCUSDT',
      seq: seq(),
      last: 1000,
      models: HoldM(),
    );
    expect(inf.result.action, 'HOLD');
    expect(inf.result.confidence, closeTo(50, 1e-9));
  });

  test('SELL branch', () async {
    final inf = await inferAndExplainForTest(
      symbol: 'BTCUSDT',
      seq: seq(),
      last: 1000,
      models: SellM(),
    );
    expect(inf.result.action, 'SELL');
    expect(inf.result.targetPrice, closeTo(990.0, 1e-9));
  });
}


