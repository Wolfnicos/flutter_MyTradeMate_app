import 'dart:io' show Platform;
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/services/exchange_rules.dart';

abstract class MarketExecution {
  Future<String> placeOrder(OrderParams p);
}

class OrderParams {
  final String symbol;
  final String side; // 'BUY' | 'SELL'
  final String type; // 'MARKET' | 'LIMIT' | 'STOP' | ...
  final double? price;
  final double quantity;
  const OrderParams({
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    this.price,
  });
}

bool get _paperTradingEnv =>
    const bool.fromEnvironment('PAPER_TRADING', defaultValue: false) ||
    Platform.environment['PAPER_TRADING'] == '1';

MarketExecution makeExecution({
  required ExchangeRules rules,
  DateTime Function()? now,
}) {
  if (_paperTradingEnv) {
    return _PaperExecutionAdapter(
      PaperBroker(
        rules,
        now: now ?? DateTime.now,
        cfg: PaperBrokerConfig(
          makerFeeBps: 1.0,
          takerFeeBps: 10.0,
          slippageBps: 0,
          partialFillFraction: 1.0,
          rulesBySymbol: const {},
        ),
      ),
    );
  }
  return RealBroker(DioBinanceClient(), rules);
}

class _PaperExecutionAdapter implements MarketExecution {
  final PaperBroker broker;
  _PaperExecutionAdapter(this.broker);
  @override
  Future<String> placeOrder(OrderParams p) async {
    final side = p.side.toUpperCase() == 'BUY' ? OrderSide.buy : OrderSide.sell;
    switch (p.type.toUpperCase()) {
      case 'MARKET':
        final o = broker.place(PaperOrderReq.market(symbol: p.symbol, side: side, quantity: p.quantity));
        return (o as PaperOrder).id;
      case 'LIMIT':
        final o = broker.place(PaperOrderReq.limit(symbol: p.symbol, side: side, price: p.price ?? 0.0, quantity: p.quantity));
        return (o as PaperOrder).id;
      default:
        throw UnsupportedError('Order type not supported in paper: ${p.type}');
    }
  }
}

class RealBroker implements MarketExecution {
  final DioBinanceClient dio;
  final ExchangeRules rules;
  RealBroker(this.dio, this.rules);
  @override
  Future<String> placeOrder(OrderParams p) async {
    // Minimal stub; integrate with your existing real trading client
    return 'real-${DateTime.now().microsecondsSinceEpoch}';
  }
}
