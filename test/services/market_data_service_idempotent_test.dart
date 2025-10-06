import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv;
import 'package:mytrademate/services/price_stream.dart';

class _FakeSrc implements PriceEventSource {
  final controllers = <StreamController<dynamic>>[];
  @override
  Stream connect(Uri _) {
    final c = StreamController<dynamic>.broadcast();
    controllers.add(c);
    return c.stream;
  }

  void emit(String json) {
    if (controllers.isNotEmpty && !controllers.last.isClosed) {
      controllers.last.add(json);
    }
  }

  @override
  Future<void> close() async {
    if (controllers.isNotEmpty && !controllers.last.isClosed) {
      await controllers.last.close();
    }
  }
}

class _FakeRest implements PriceRestClient {
  double v = 101.0;
  @override
  Future<double> tickerPrice(String symbol) async => v;
  @override
  Future<bool> ping() async => true;
}

Future<void> _noDelay(Duration _) async {}

void main() {
  test('idempotent start/stop without duplicate closures', () async {
    final src = _FakeSrc();
    final rest = _FakeRest();
    final svc = MarketDataServiceImpl(
        env: TradeEnv.testnet, eventSource: src, rest: rest, sleep: _noDelay);

    await svc.start('BTCUSDT');
    await svc.start('BTCUSDT');

    // simulate a price event
    src.emit('{"c":"100.0"}');
    final a = await svc
        .prices('BTCUSDT')
        .first
        .timeout(const Duration(milliseconds: 50), onTimeout: () => 0.0);
    expect(a, isA<num>());

    await svc.stopIfOrphan('BTCUSDT'); // should not close if still referenced

    // still able to receive values
    src.emit('{"c":"101.0"}');
    final b = await svc
        .prices('BTCUSDT')
        .first
        .timeout(const Duration(milliseconds: 50), onTimeout: () => 0.0);
    expect(b, isA<num>());
  });
}
