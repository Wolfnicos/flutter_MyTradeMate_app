import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:test/test.dart' as test show Skip;

class _FakeClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 128}) async =>
      List.generate(
          limit, (k) => [0, 0, 0, 0, 1000 + k.toDouble(), 0, 0, 0, 0, 0, 0, 0]);

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
      (
        probUp: 0.65,
        nextReturn: 0.02,
        volatility: 0.16
      ); // HIGH - crypto volatility

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.65, nextReturn: 0.02, volatility: 0.16);
}

class _HoldModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (
        probUp: 0.50,
        nextReturn: 0.0,
        volatility: 0.06
      ); // MEDIUM - crypto volatility

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.50, nextReturn: 0.0, volatility: 0.06);
}

class _SellModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.35, nextReturn: -0.01, volatility: 0.03); // LOW

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.35, nextReturn: -0.01, volatility: 0.03);
}

@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  test('AIService → BUY branch at/above 0.60 (crypto threshold)', () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _BuyModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'BUY');
    expect(r.confidence,
        greaterThanOrEqualTo(60)); // 0.65 → 65% (crypto-optimized)
    expect(r.volatility, 'HIGH'); // crypto volatility threshold >= 0.15
  });

  test('AIService → HOLD branch between thresholds (0.40 < prob < 0.60)',
      () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _HoldModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'HOLD');
    expect(r.confidence, inInclusiveRange(40, 60)); // ~50% (crypto range)
    expect(r.targetPrice, greaterThan(0));
    expect(r.volatility, 'MEDIUM'); // crypto volatility: 0.05 <= vol < 0.15
  });

  test('AIService → SELL branch at lower bound (<= 0.40)', () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _SellModels());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'SELL');
    expect(r.confidence, lessThanOrEqualTo(40)); // 35% (crypto threshold)
    expect(r.targetPrice, greaterThan(0));
    expect(r.volatility, 'LOW'); // crypto volatility < 0.05
  });
}
