import 'package:flutter/material.dart';
import '../../core/trading_prefs.dart';

class TradeSheet extends StatelessWidget {
  final TradingPrefs prefs;
  final String symbol;
  const TradeSheet({super.key, required this.prefs, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final isTest = prefs.env == TradeEnv.testnet;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('Place order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isTest) const Chip(label: Text('TESTNET')),
          ]),
          const SizedBox(height: 12),
          Text(
              'Symbol: $symbol • Market • Quote ${prefs.fixedQuote.toStringAsFixed(0)} USDT',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, 'BUY'),
                  child: const Text('BUY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'SELL'),
                  child: const Text('SELL'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

