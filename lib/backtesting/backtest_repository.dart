import 'dart:io';

import 'package:flutter/foundation.dart';

import 'backtest_result.dart';

/// Persists backtest results as JSON and CSV under build/reports/backtests
class BacktestRepository {
  final Directory _dir;

  BacktestRepository._(this._dir);

  static Future<BacktestRepository> create() async {
    final dir = Directory('build/reports/backtests');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return BacktestRepository._(dir);
  }

  Future<File> saveJson(BacktestResult r) async {
    final name = _fileBase(r);
    final f = File('${_dir.path}/$name.json');
    await f.writeAsString(r.toJsonString());
    if (kDebugMode) debugPrint('💾 Saved JSON: ${f.path}');
    return f;
  }

  Future<File> saveCsv(BacktestResult r) async {
    final name = _fileBase(r);
    final f = File('${_dir.path}/$name.csv');
    final sb = StringBuffer();
    sb.writeln('time,equity');
    for (int i = 0; i < r.times.length; i++) {
      sb.writeln('${r.times[i].toIso8601String()},${r.equity[i].toStringAsFixed(6)}');
    }
    await f.writeAsString(sb.toString());
    if (kDebugMode) debugPrint('💾 Saved CSV: ${f.path}');
    return f;
  }

  String _fileBase(BacktestResult r) {
    final s0 = r.start.toIso8601String().replaceAll(':', '-');
    final s1 = r.end.toIso8601String().replaceAll(':', '-');
    final base = StringBuffer()
      ..write(r.symbol)
      ..write('_')
      ..write(r.interval)
      ..write('_')
      ..write(s0)
      ..write('_')
      ..write(s1);
    return base.toString();
  }
}


