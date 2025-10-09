import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv;

/// Small abstraction over REST price endpoints, easy to fake in tests.
abstract class PriceRestClient {
  Future<double> tickerPrice(String symbol);
  Future<bool> ping();
}

class DefaultPriceRestClient implements PriceRestClient {
  final DioBinanceClient _client;

  DefaultPriceRestClient({required TradeEnv env})
      : _client = DioBinanceClient(env: env);

  @visibleForTesting
  DefaultPriceRestClient.fromClient(DioBinanceClient c) : _client = c;

  @override
  Future<bool> ping() => _client.ping();

  @override
  Future<double> tickerPrice(String symbol) => _client.tickerPrice(symbol);
}


