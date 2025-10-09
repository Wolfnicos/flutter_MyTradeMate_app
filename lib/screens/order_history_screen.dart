import 'package:flutter/material.dart';
import 'package:mytrademate/src/core/order_history.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = OrderHistoryRepository.instance.getOrders(TradeEnv.testnet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: FutureBuilder<List<Order>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data ?? const <Order>[];
          if (orders.isEmpty) {
            return const Center(child: Text('No recent orders'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                title: Text('${o.symbol} • ${o.side} • ${o.status}'),
                subtitle: Text(o.ts.toLocal().toString()),
                trailing: Text(o.quoteQty.toStringAsFixed(2)),
              );
            },
          );
        },
      ),
    );
  }
}



