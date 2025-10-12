import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CostsConfig {
  final double fee, slippage, spread;
  const CostsConfig(
      {required this.fee, required this.slippage, required this.spread});

  static Future<CostsConfig> load() async {
    final s = await rootBundle.loadString('assets/config/costs.json');
    final m = (json.decode(s) as Map).cast<String, dynamic>();
    double d(String k) => ((m[k] as num?) ?? 0).toDouble();
    return CostsConfig(
        fee: d('fee'), slippage: d('slippage'), spread: d('spread'));
  }
}
