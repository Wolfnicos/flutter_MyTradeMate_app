import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:test/test.dart' as test show Skip;

class _FakeClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 128}) async {
    return List.generate(
        limit, (k) => [0, 0, 0, 0, 1000 + k.toDouble(), 0, 0, 0, 0, 0, 0, 0]);
  }

  @override
  Future<double> tickerPrice(String s) async => 1111.0;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async =>
      {'lastPrice': 1111.0, 'prevClosePrice': 1111.0};
}

class _ModelsAdapterBuy implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.70, nextReturn: 0.02, volatility: 0.12);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.70, nextReturn: 0.02, volatility: 0.12);
}

class _ModelsAdapterHold implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.50, nextReturn: 0.00, volatility: 0.04);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.50, nextReturn: 0.00, volatility: 0.04);
}

class _ModelsAdapterSell implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.30, nextReturn: -0.01, volatility: 0.02);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.30, nextReturn: -0.01, volatility: 0.02);
}

@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  test('AIService → BUY branch', () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _ModelsAdapterBuy());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'BUY');
    expect(r.confidence, greaterThan(55));
  });

  test('AIService → HOLD branch', () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _ModelsAdapterHold());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'HOLD');
    expect(r.confidence, closeTo(50, 0.01));
  });

  test('AIService → SELL branch', () async {
    final svc = AIService(
        client: _FakeClient(),
        fb: const FeatureBuilder(),
        models: _ModelsAdapterSell());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'SELL');
    expect(r.confidence, lessThan(45));
  });
}
