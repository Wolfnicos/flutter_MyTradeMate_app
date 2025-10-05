import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';
import 'package:mytrademate/services/mtm_models.dart';

class _FakeClient implements BinanceClientLike {
  @override
  Future<List<List<num>>> klines(String symbol, String interval, {int limit = 50}) async {
    return const [
      [0, 100, 102, 99, 101, 123],
      [1, 101, 103, 100, 102, 234],
      [2, 102, 104, 101, 103, 345],
    ];
  }

  @override
  Future<double> tickerPrice(String symbol) async => 101.0;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async => {
        'symbol': symbol,
        'lastPrice': '101.0',
        'prevClosePrice': '99.0',
      };
}

class _FakeModels implements ModelsAdapter {
  @override
  List<String> get featCols => const ['last', 'ret1', 'sma5', 'sma20', 'rsi14'];

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(
      Map<String, double> features) async {
    return (probUp: 0.8, nextReturn: 0.02, volatility: 0.05);
  }

  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(
      List<List<double>> seq) async {
    return (probUp: 0.8, nextReturn: 0.02, volatility: 0.05);
  }
}

void main() {
  test('getPrediction offline returns BUY with explain-ish fields stable', () async {
    final svc = AIService(client: _FakeClient(), models: _FakeModels());

    final res = await svc.getPrediction(' btc/usd ');
    expect(res.action, equals('BUY'));
    expect(res.confidence, greaterThan(50));
    expect(res.targetPrice, greaterThan(0));
  });

  test('toBinanceSymbolForTest normalizes whitespace/case and USD → USDT', () {
    expect(toBinanceSymbolForTest(' ethusdt '), 'ETHUSDT');
    expect(toBinanceSymbolForTest(' btc/usd '), 'BTCUSDT');
  });

  test('volLabelForTest buckets thresholds', () {
    expect(volLabelForTest(0.0), 'LOW');
    expect(volLabelForTest(0.04), 'MEDIUM');
    expect(volLabelForTest(0.12), 'HIGH');
  });
}


