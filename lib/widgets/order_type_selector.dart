import 'package:flutter/material.dart';

/// Selector modern pentru tipuri de ordine (Binance 2025 style)
enum OrderType {
  limit,
  market,
  stopLimit,
  stopMarket,
  trailingStop,
  oco,
  algoOrder,
}

class OrderTypeSelector extends StatelessWidget {
  final OrderType selected;
  final ValueChanged<OrderType> onChanged;
  
  const OrderTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...OrderType.values.map((type) => _OrderTypeTile(
          type: type,
          selected: type == selected,
          onTap: () => onChanged(type),
        )),
      ],
    );
  }
}

class _OrderTypeTile extends StatelessWidget {
  final OrderType type;
  final bool selected;
  final VoidCallback onTap;
  
  const _OrderTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = _getOrderTypeInfo(type);
    
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withValues(alpha: 25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.withValues(alpha: 77),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              info.icon,
              color: selected ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  _OrderTypeInfo _getOrderTypeInfo(OrderType type) {
    switch (type) {
      case OrderType.limit:
        return const _OrderTypeInfo(
          icon: Icons.horizontal_rule,
          title: 'Limit',
          description: 'Buy or Sell at a specific price or better',
        );
      case OrderType.market:
        return const _OrderTypeInfo(
          icon: Icons.flash_on,
          title: 'Market',
          description: 'Buy or Sell at the best available market price',
        );
      case OrderType.stopLimit:
        return const _OrderTypeInfo(
          icon: Icons.trending_up,
          title: 'Stop Limit',
          description: 'Triggers a Limit order when Stop price is reached.',
        );
      case OrderType.stopMarket:
        return const _OrderTypeInfo(
          icon: Icons.stop,
          title: 'Stop Market',
          description: 'Triggers a Market order when Stop price is reached',
        );
      case OrderType.trailingStop:
        return const _OrderTypeInfo(
          icon: Icons.show_chart,
          title: 'Trailing Stop',
          description: 'Places an order when the price reaches the predefined point',
        );
      case OrderType.oco:
        return const _OrderTypeInfo(
          icon: Icons.compare_arrows,
          title: 'OCO',
          description: 'Places two orders at once. When either is triggered, the other is canceled',
        );
      case OrderType.algoOrder:
        return const _OrderTypeInfo(
          icon: Icons.psychology,
          title: 'Algo Order',
          description: 'Execute orders with intelligent algorithmic order strategies',
        );
    }
  }
}

class _OrderTypeInfo {
  final IconData icon;
  final String title;
  final String description;
  
  const _OrderTypeInfo({
    required this.icon,
    required this.title,
    required this.description,
  });
}



