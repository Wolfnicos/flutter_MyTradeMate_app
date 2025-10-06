import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TradeEnv { testnet, live }

class Order {
  final String id;
  final String symbol;
  final String side; // "BUY" / "SELL"
  final double quoteQty; // suma în USDT trimisă
  final double? executedQty; // cantitatea de bază executată (ex: BTC)
  final String status; // NEW / FILLED / PARTIALLY_FILLED / REJECTED etc.
  final TradeEnv env;
  final DateTime ts;

  Order({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quoteQty,
    this.executedQty,
    required this.status,
    required this.env,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side,
        'quoteQty': quoteQty,
        'executedQty': executedQty,
        'status': status,
        'env': env.name,
        'ts': ts.toIso8601String(),
      };

  static Order fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        side: j['side'] as String,
        quoteQty: (j['quoteQty'] as num).toDouble(),
        executedQty: j['executedQty'] == null
            ? null
            : (j['executedQty'] as num).toDouble(),
        status: j['status'] as String,
        env: (j['env'] as String) == 'live' ? TradeEnv.live : TradeEnv.testnet,
        ts: DateTime.parse(j['ts'] as String),
      );
}

class OrderHistoryRepository {
  OrderHistoryRepository._();
  static final OrderHistoryRepository instance = OrderHistoryRepository._();

  static String _key(TradeEnv env) =>
      env == TradeEnv.testnet ? 'history_testnet' : 'history_live';

  Future<List<Order>> getOrders(TradeEnv env) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(env));
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Order.fromJson).toList();
  }

  Future<void> addOrder(Order o) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(o.env);
    final cur = await getOrders(o.env);
    final updated = [o, ...cur];
    // păstrează maxim 20
    final trimmed = updated.take(20).toList();
    await prefs.setString(
      key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear(TradeEnv env) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(env));
  }
}
