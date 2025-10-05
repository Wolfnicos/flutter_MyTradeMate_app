import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/market_data_service.dart';
import 'package:mytrademate/services/price_rest_client.dart';
import 'package:mytrademate/services/price_stream.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv;

class _SilentSrc implements PriceEventSource {
  @override
  Stream connect(Uri uri) => const Stream.empty();
  @override
  Future<void> close() async {}
}

class _StubRest implements PriceRestClient {
  final double returnPrice;
  _StubRest(this.returnPrice);
  @override
  Future<double> tickerPrice(String symbol) async => returnPrice;
  @override
  Future<bool> ping() async => true;
}

Future<void> _noDelay(Duration _) async {}

void main() {
  test('refreshNow uses REST and pushes value', () async {
    final rest = _StubRest(123.45);
    final svc = MarketDataServiceImpl(env: TradeEnv.testnet, eventSource: _SilentSrc(), rest: rest, sleep: _noDelay);
    await svc.start('BTCUSDT');
    // Subscribe before triggering refresh to avoid race on broadcast
    final next = svc.prices('BTCUSDT').first.timeout(const Duration(milliseconds: 500));
    final v = await svc.refreshNow('BTCUSDT');
    expect(v, 123.45);
    final got = await next;
    expect(got, closeTo(123.45, 1e-9));
  }, timeout: const Timeout(Duration(seconds: 5)));
}


