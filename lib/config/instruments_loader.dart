import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class InstrumentsConfig {
  final String exchange;
  final String quote;
  final List<String> symbols;
  const InstrumentsConfig(
      {required this.exchange, required this.quote, required this.symbols});

  static Future<InstrumentsConfig> load() async {
    final s = await rootBundle.loadString('assets/config/instruments.json');
    final m = (json.decode(s) as Map).cast<String, dynamic>();
    final syms =
        ((m['symbols'] as List?) ?? const []).map((e) => e.toString()).toList();
    return InstrumentsConfig(
      exchange: (m['exchange'] ?? '').toString(),
      quote: (m['quote'] ?? '').toString(),
      symbols: syms,
    );
  }
}
