import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/feature_builder.dart';

class _ErrClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String s, String i, {int limit = 200}) async {
    throw Exception('klines unavailable');
  }

  @override
  Future<double> tickerPrice(String s) async => 1000.0; // fallback source

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async => {
        'lastPrice': 1000.0,
        'prevClosePrice': 990.0,
      };
}

class _Models implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
          Map<String, double> features) async =>
      (probUp: 0.56, nextReturn: 0.01, volatility: 0.05);

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})>
      predictAllFromSequence(List<List<double>> seq) async =>
          (probUp: 0.56, nextReturn: 0.01, volatility: 0.05);
}

void main() {
  test('AIService falls back to ticker features when klines fail', () async {
    final svc = AIService(
        client: _ErrClient(), fb: const FeatureBuilder(), models: _Models());
    final r = await svc.inferForSymbol('BTCUSDT');
    expect(r.action, 'BUY');
    expect(r.confidence, greaterThan(55));
    expect(r.targetPrice, greaterThan(0));
  });
}

