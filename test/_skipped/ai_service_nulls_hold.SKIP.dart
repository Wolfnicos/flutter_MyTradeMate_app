import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:test/test.dart' as test show Skip;

class _ClientOk implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 200}) async =>
      List.generate(64, (k) => [0, 0, 0, 0, 1000 + k, 0, 0, 0, 0, 0, 0, 0]);

  @override
  Future<double> tickerPrice(String s) async => 1000.0;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async =>
      {'lastPrice': 1000.0, 'prevClosePrice': 1000.0};
}

class _NullModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: null, nextReturn: null, volatility: null);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: null, nextReturn: null, volatility: null);
}

@test.Skip(
    'Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')
void main() {
  test('AIService handles null model outputs → HOLD, defaults', () async {
    final svc = AIService(
      client: _ClientOk(),
      fb: const FeatureBuilder(),
      models: _NullModels(),
    );
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'HOLD');
    expect(r.confidence, closeTo(50, 0.001));
    expect(r.targetPrice, greaterThan(0));
  });
}
