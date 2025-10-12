import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class TfSpec {
  final int seq;
  final int horizon;
  final double flatBandBps;
  const TfSpec(
      {required this.seq, required this.horizon, required this.flatBandBps});
  factory TfSpec.fromJson(Map<String, dynamic> j) => TfSpec(
        seq: (j['seq'] as num).toInt(),
        horizon: (j['horizon'] as num).toInt(),
        flatBandBps: (j['flat_band_bps'] as num).toDouble(),
      );
}

class TimeframesConfig {
  final Map<String, TfSpec> tfs;
  const TimeframesConfig(this.tfs);

  static Future<TimeframesConfig> load() async {
    final s = await rootBundle.loadString('assets/config/timeframes.json');
    final m = json.decode(s) as Map<String, dynamic>;
    final raw = (m['tfs'] as Map).cast<String, dynamic>();
    final parsed = <String, TfSpec>{};
    raw.forEach((k, v) =>
        parsed[k] = TfSpec.fromJson((v as Map).cast<String, dynamic>()));
    return TimeframesConfig(parsed);
  }
}
