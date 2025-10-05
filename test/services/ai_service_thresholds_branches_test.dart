import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';

class _FakeClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 128}) async =>
      List.generate(limit, (k) => [0, 0, 0, 0, 1000 + k.toDouble(), 0, 0, 0, 0, 0, 0, 0]);

  @override
  Future<double> tickerPrice(String s) async => 1111.0;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async =>
      {'lastPrice': 1111.0, 'prevClosePrice': 1100.0};
}

class _BuyModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.56, nextReturn: 0.02, volatility: 0.12); // HIGH

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
          List<List<double>> seq) async =>
      (probUp: 0.56, nextReturn: 0.02, volatility: 0.12);
}

class _HoldModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.54, nextReturn: 0.0, volatility: 0.04); // MEDIUM

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
          List<List<double>> seq) async =>
      (probUp: 0.54, nextReturn: 0.0, volatility: 0.04);
}

class _SellModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.45, nextReturn: -0.01, volatility: 0.02); // LOW

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
          List<List<double>> seq) async =>
      (probUp: 0.45, nextReturn: -0.01, volatility: 0.02);
}

void main() {
  test('AIService → BUY branch at/above 0.55', () async {
    final svc = AIService(client: _FakeClient(), fb: const FeatureBuilder(), models: _BuyModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'BUY');
    expect(r.confidence, greaterThanOrEqualTo(55)); // 0.56 → 56%
    expect(r.volatility, 'HIGH');
  });

  test('AIService → HOLD branch between thresholds', () async {
    final svc = AIService(client: _FakeClient(), fb: const FeatureBuilder(), models: _HoldModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'HOLD');
    expect(r.confidence, inInclusiveRange(45, 55)); // ~54%
    expect(r.targetPrice, greaterThan(0));
    expect(r.volatility, 'MEDIUM');
  });

  test('AIService → SELL branch at lower bound (<= 0.45)', () async {
    final svc = AIService(client: _FakeClient(), fb: const FeatureBuilder(), models: _SellModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'SELL');
    expect(r.confidence, lessThanOrEqualTo(45)); // 45%
    expect(r.targetPrice, greaterThan(0));
    expect(r.volatility, 'LOW');
  });
}


