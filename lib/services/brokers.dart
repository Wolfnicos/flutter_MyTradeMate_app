import 'dart:io' show Platform;
import 'package:mytrademate/services/paper_broker.dart';
import 'package:mytrademate/services/dio_binance_client.dart';
import 'package:mytrademate/services/exchange_rules.dart';
import 'package:mytrademate/src/core/trading_prefs.dart' show TradeEnv;

abstract class MarketExecution {
  Future<String> placeOrder(OrderParams p);
}

class OrderParams {
  final String symbol;
  final String side; // 'BUY' | 'SELL'
  final String type; // 'MARKET' | 'LIMIT' | 'STOP_LOSS' | 'STOP_LOSS_LIMIT' | 'TAKE_PROFIT' | 'TAKE_PROFIT_LIMIT' | 'OCO' | 'TRAILING_STOP_MARKET'
  final double? price;
  final double quantity;
  final double? stopPrice; // For STOP_LOSS, STOP_LOSS_LIMIT, TAKE_PROFIT, etc.
  final double? stopLimitPrice; // For OCO
  final double? callbackRate; // For TRAILING_STOP_MARKET (0.1 to 5.0)
  final String? timeInForce; // GTC, IOC, FOK
  
  const OrderParams({
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    this.price,
    this.stopPrice,
    this.stopLimitPrice,
    this.callbackRate,
    this.timeInForce,
  });
}

bool get _paperTradingEnv =>
    const bool.fromEnvironment('PAPER_TRADING', defaultValue: false) ||
    Platform.environment['PAPER_TRADING'] == '1';

MarketExecution makeExecution({
  required ExchangeRules rules,
  DateTime Function()? now,
  TradeEnv env = TradeEnv.testnet,
}) {
  if (_paperTradingEnv) {
    return _PaperExecutionAdapter(
      PaperBroker(
        rules,
        now: now ?? DateTime.now,
        cfg: const PaperBrokerConfig(
          makerFeeBps: 1.0,
          takerFeeBps: 10.0,
          slippageBps: 0,
          partialFillFraction: 1.0,
          rulesBySymbol: {},
        ),
      ),
    );
  }
  return RealBroker(DioBinanceClient(env: env), rules);
}

class _PaperExecutionAdapter implements MarketExecution {
  final PaperBroker broker;
  _PaperExecutionAdapter(this.broker);
  @override
  Future<String> placeOrder(OrderParams p) async {
    final side = p.side.toUpperCase() == 'BUY' ? OrderSide.buy : OrderSide.sell;
    switch (p.type.toUpperCase()) {
      case 'MARKET':
        final o = broker.place(PaperOrderReq.market(
            symbol: p.symbol, side: side, quantity: p.quantity));
        return (o as PaperOrder).id;
      case 'LIMIT':
        final o = broker.place(PaperOrderReq.limit(
            symbol: p.symbol,
            side: side,
            price: p.price ?? 0.0,
            quantity: p.quantity));
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
    // Apply exchange rules for quantity precision if available
    final qty = p.quantity;
    
    Map<String, dynamic> result;
    
    switch (p.type.toUpperCase()) {
      case 'MARKET':
        // Use quoteOrderQty for market orders (amount in USDT)
        final quoteQty = p.price != null ? qty * p.price! : qty * 100; // fallback estimate
        result = await dio.newMarketOrderQuote(
          symbol: p.symbol,
          side: p.side,
          quoteOrderQty: quoteQty,
        );
        break;
        
      case 'LIMIT':
        if (p.price == null) {
          throw ArgumentError('LIMIT order requires price');
        }
        result = await dio.newLimitOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          price: p.price!,
          timeInForce: p.timeInForce ?? 'GTC',
        );
        break;
        
      case 'STOP_LOSS':
        if (p.stopPrice == null) {
          throw ArgumentError('STOP_LOSS order requires stopPrice');
        }
        result = await dio.newStopLossOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          stopPrice: p.stopPrice!,
        );
        break;
        
      case 'STOP_LOSS_LIMIT':
        if (p.price == null || p.stopPrice == null) {
          throw ArgumentError('STOP_LOSS_LIMIT order requires price and stopPrice');
        }
        result = await dio.newStopLossLimitOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          price: p.price!,
          stopPrice: p.stopPrice!,
          timeInForce: p.timeInForce ?? 'GTC',
        );
        break;
        
      case 'TAKE_PROFIT':
        if (p.stopPrice == null) {
          throw ArgumentError('TAKE_PROFIT order requires stopPrice');
        }
        result = await dio.newTakeProfitOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          stopPrice: p.stopPrice!,
        );
        break;
        
      case 'TAKE_PROFIT_LIMIT':
        if (p.price == null || p.stopPrice == null) {
          throw ArgumentError('TAKE_PROFIT_LIMIT order requires price and stopPrice');
        }
        result = await dio.newTakeProfitLimitOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          price: p.price!,
          stopPrice: p.stopPrice!,
          timeInForce: p.timeInForce ?? 'GTC',
        );
        break;
        
      case 'OCO':
        if (p.price == null || p.stopPrice == null || p.stopLimitPrice == null) {
          throw ArgumentError('OCO order requires price, stopPrice, and stopLimitPrice');
        }
        result = await dio.newOCOOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          price: p.price!,
          stopPrice: p.stopPrice!,
          stopLimitPrice: p.stopLimitPrice!,
          stopLimitTimeInForce: p.timeInForce ?? 'GTC',
        );
        break;
        
      case 'TRAILING_STOP_MARKET':
        if (p.callbackRate == null) {
          throw ArgumentError('TRAILING_STOP_MARKET order requires callbackRate (0.1 to 5.0)');
        }
        result = await dio.newTrailingStopOrder(
          symbol: p.symbol,
          side: p.side,
          quantity: qty,
          callbackRate: p.callbackRate!,
        );
        break;
        
      default:
        throw UnsupportedError('Order type ${p.type} not supported');
    }
    
    // Return orderId or orderListId (for OCO)
    final orderId = result['orderId']?.toString() ?? 
                    result['orderListId']?.toString() ??
                    'unknown-${DateTime.now().microsecondsSinceEpoch}';
    return orderId;
  }
}
