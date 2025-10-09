import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';
import 'package:test/test.dart' as test show Skip;

class _ClientTicker24hFails implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String symbol, String interval,
      {int limit = 200}) async {
    throw Exception('klines down');
  }

  @override
  Future<double> tickerPrice(String symbol) async => 1000.0;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async =>
      throw Exception('24h down');
}

class _ModelsHold implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.5, nextReturn: 0.0, volatility: 0.04);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.5, nextReturn: 0.0, volatility: 0.04);
}
@test.Skip('Legacy AIService pipeline — to be reworked to AILocator. TODO(#migrate-ai-legacy)')

void main() {
  test('AIService falls back when 24h and klines fail', () async {
    final svc = AIService(
      client: _ClientTicker24hFails(),
      models: _ModelsHold(),
      fb: const FeatureBuilder(),
    );
    final r = await svc.inferForSymbol('btc/usd');
    expect(r.action, 'HOLD');
    expect(r.confidence, closeTo(50, 0.1));
    expect(r.targetPrice, greaterThan(0));
  });
}


