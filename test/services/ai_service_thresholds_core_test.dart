import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/ai_service.dart';

class _FakeClient implements BinanceClientLike {
  Map<String, dynamic> _t = {
    'symbol': 'BTCUSDT',
    'lastPrice': '101.0',
    'prevClosePrice': '100.0',
  };
  List<List<num>> _kl = const [
    [0, 100, 102, 99, 101, 123],
    [1, 101, 103, 100, 102, 234],
    [2, 102, 104, 101, 103, 345],
  ];

  void setTicker(Map<String, dynamic> t) => _t = t;
  void setKlines(List<List<num>> k) => _kl = k;

  @override
  Future<Map<String, dynamic>> ticker24h(String symbol) async => _t;

  @override
  Future<double> tickerPrice(String symbol) async => 101.0;

  @override
  Future<List<List<num>>> klines(String symbol, String interval, {int limit = 50}) async => _kl;
}

class _FixedModels implements ModelsAdapter {
  final double? prob;
  const _FixedModels(this.prob);
  @override
  List<String> get featCols => const ['last'];
  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(Map<String, double> features) async {
    return (probUp: prob, nextReturn: 0.02, volatility: 0.05);
  }
  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(List<List<double>> seq) async {
    return (probUp: prob, nextReturn: 0.02, volatility: 0.05);
  }
}

void main() {
  test('BUY branch (p >= 0.55)', () async {
    final svc = AIService(client: _FakeClient(), models: const _FixedModels(0.85));
    final res = await svc.getPrediction('BTCUSDT');
    expect(res.action, 'BUY');
    expect(res.confidence, greaterThan(0));
  });

  test('SELL branch (p <= 0.45)', () async {
    final svc = AIService(client: _FakeClient(), models: const _FixedModels(0.05));
    final res = await svc.getPrediction('BTCUSDT');
    expect(res.action, 'SELL');
  });

  test('HOLD branch (between thresholds)', () async {
    final svc = AIService(client: _FakeClient(), models: const _FixedModels(0.50));
    final res = await svc.getPrediction('BTCUSDT');
    expect(res.action, 'HOLD');
  });

  test('Model returns null → HOLD fallback', () async {
    final svc = AIService(client: _FakeClient(), models: const _FixedModels(null));
    final res = await svc.getPrediction('BTCUSDT');
    expect(res.action, 'HOLD');
  });
}


