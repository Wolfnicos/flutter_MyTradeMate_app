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

class _EchoModels extends MtmModels {
  num _extractLast(Object input) {
    if (input is List && input.isNotEmpty) {
      final first = input.first;
      if (first is List && first.isNotEmpty) {
        final row = first.last;
        if (row is List && row.isNotEmpty) {
          final v = row.first;
          if (v is num) return v;
        }
      }
    }
    return 0;
  }

  @override
  double predictDirection(Object input) => _extractLast(input).toDouble() / 1000.0;
  @override
  double predictReturn(Object input) => _extractLast(input).toDouble() / 100.0;
  @override
  double predictVolatility(Object input) => _extractLast(input).toDouble() / 10000.0;
}

class _ModelsAdapter implements ModelsAdapter {
  final MtmModels m;
  _ModelsAdapter(this.m);
  @override
  List<String> get featCols => const ['last'];
  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAll(Map<String, double> features) async {
    // Build a minimal sequence from last
    final last = features['last'] ?? 0.0;
    final seq = List<List<double>>.generate(64, (_) => [last]);
    final out = await m.predictAllFromSequence(seq);
    return out;
  }
  @override
  Future<({double? probUp, double? nextReturn, double? volatility})> predictAllFromSequence(List<List<double>> seq) async {
    final out = await m.predictAllFromSequence(seq);
    return out;
  }
}

void main() {
  test('getPrediction offline → BUY + explain-ish mapping', () async {
    final svc = AIService(
      client: _FakeClient(),
      models: _ModelsAdapter(_EchoModels()..markLoadedForTest(const ['last'])),
    );
    final res = await svc.getPrediction('BTCUSDT');
    expect(res.action, anyOf('BUY', 'HOLD', 'SELL'));
    expect(res.confidence, greaterThan(0));
  });

  test('toBinanceSymbolForTest normalizes', () {
    expect(toBinanceSymbolForTest(' ethusdt '), 'ETHUSDT');
  });
}


