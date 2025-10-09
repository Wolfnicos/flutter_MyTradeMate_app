import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:test/test.dart' as test show Skip;

class _FakeClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String sym, String interval,
      {int limit = 128}) async {
    return List.generate(limit, (i) => [0, 0, 0, 0, 1000 + i, 0]);
  }

  @override
  Future<double> tickerPrice(String sym) async => 1123.45;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async =>
      {'lastPrice': 1123.45, 'prevClosePrice': 1120.00};
}

class _FakeModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
      Map<String, double> features) async {
    return (probUp: 0.62, nextReturn: 0.01, volatility: 0.12);
  }

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async {
    return (probUp: 0.62, nextReturn: 0.01, volatility: 0.12);
  }
}
@test.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')

void main() {
  test('AIService produces deterministic BUY with confidence & target',
      () async {
    final svc = AIService(
      client: _FakeClient(),
      models: _FakeModels(),
      fb: const FeatureBuilder(['last', 'ret1', 'sma5', 'sma20', 'rsi14']),
    );
    final res = await svc.inferForSymbol('BTCUSDT');
    expect(res.action, 'BUY');
    expect(res.confidence, greaterThan(55));
    expect(res.targetPrice, greaterThan(0));
  });
}


