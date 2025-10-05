import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:mytrademate/services/ai_service.dart' show BinanceClientLike, ModelsAdapter;

class _OkClient2 implements BinanceClientLike {
  @override
  Future<Map<String, dynamic>> ticker24h(String s) async => {'lastPrice': 100.0, 'prevClosePrice': 100.0};
  @override
  Future<double> tickerPrice(String s) async => 100.0;
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 200}) async =>
      List.generate(64, (k) => [0, 0, 0, 0, 100 + k, 0, 0, 0, 0, 0, 0, 0]);
}

class _HoldModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
      Map<String, double> features) async => (probUp: 0.50, nextReturn: 0.0, volatility: 0.05);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
          List<List<double>> seq) async =>
      (probUp: 0.50, nextReturn: 0.0, volatility: 0.05);
}

void main() {
  test('AIService selects HOLD when 0.45 < probUp < 0.55', () async {
    final svc = AIService(client: _OkClient2(), fb: const FeatureBuilder(), models: _HoldModels());
    final r = await svc.inferForSymbol('ETHUSDT');
    expect(r.action, 'HOLD');
    expect(r.confidence, closeTo(50.0, 0.001));
  });
}


