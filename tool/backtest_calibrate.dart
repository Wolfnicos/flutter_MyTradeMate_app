// dart run tool/backtest_calibrate.dart --in data.json --calibrator platt --out assets/models/calibration.json
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:mytrademate/services/calibration.dart';

class RowRec { final int ts; final String sym; final int y; final double p; RowRec(this.ts,this.sym,this.y,this.p); }

void usage() {
  print('Usage: dart run tool/backtest_calibrate.dart --in <file.json|csv> [--bins 15] --calibrator <identity|platt|isotonic> --out <calibration.json>');
}

Future<void> main(List<String> args) async {
  final arg = Map.fromEntries(List.generate(args.length ~/ 2, (i) => MapEntry(args[i*2], args[i*2+1])));
  final input = arg['--in'];
  final out = arg['--out'] ?? 'assets/models/calibration.json';
  final method = (arg['--calibrator'] ?? 'identity').toString().toLowerCase();
  final bins = int.tryParse(arg['--bins'] ?? '15') ?? 15;
  final seed = int.tryParse(arg['--seed'] ?? '1337') ?? 1337;
  if (input == null) { usage(); exit(1); }

  final rows = await _readRows(input);
  if (rows.isEmpty) { print('No rows'); exit(1); }

  // naive time split: first 80% train, last 20% valid
  rows.sort((a,b)=>a.ts.compareTo(b.ts));
  final k = (rows.length * 0.8).floor();
  final train = rows.sublist(0,k);
  final valid = rows.sublist(k);

  Calibrator calib;
  switch (method) {
    case 'platt':
      calib = _fitPlatt(train, l2: 1e-3);
      break;
    case 'isotonic':
      calib = _fitIsotonic(train, bins: bins, minPerBin: 200);
      break;
    default:
      calib = const IdentityCalibrator();
  }

  final pCal = valid.map((r)=>calib.calibrate(r.p)).toList();
  final y = valid.map((r)=>r.y).toList();
  final rb = reliabilityBins(pCal, y, bins: bins);
  final ece = expectedCalibrationError(rb, valid.length);
  final brier = brierScore(pCal, y);
  final ll = logLoss(pCal, y);
  final auc = rocAuc(pCal, y);

  // Write assets/models/calibration.json
  await File(out).create(recursive: true);
  final meta = {
    'version': 1,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'calibrator': method,
    'params': _paramsOf(calib),
    'train_meta': {
      'symbols': rows.map((e)=>e.sym).toSet().toList(),
      'window': '${DateTime.fromMillisecondsSinceEpoch(rows.first.ts).toUtc().toIso8601String()}..${DateTime.fromMillisecondsSinceEpoch(rows.last.ts).toUtc().toIso8601String()}',
      'n_train': train.length,
      'n_valid': valid.length,
      'ece': ece,
      'brier': brier,
      'logloss': ll,
      'roc_auc': auc,
      'seed': seed,
      'commit': (await _gitSha())
    }
  };
  await File(out).writeAsString(const JsonEncoder.withIndent('  ').convert(meta));

  // artifacts report
  final reportPath = 'artifacts/calibration_report.json';
  await File(reportPath).create(recursive: true);
  final rep = {
    'ece': ece,
    'brier': brier,
    'logloss': ll,
    'roc_auc': auc,
    'n_bins_nonempty': rb.length,
    'seed': seed,
    'commit': (await _gitSha()),
    'bins': rb.map((b)=>{'lo':b.lo,'hi':b.hi,'n':b.n,'meanPred':b.meanPred,'meanTrue':b.meanTrue}).toList(),
  };
  await File(reportPath).writeAsString(const JsonEncoder.withIndent('  ').convert(rep));
  print('Wrote $out and $reportPath');
}

Future<List<RowRec>> _readRows(String path) async {
  final f = File(path);
  final s = await f.readAsString();
  if (path.endsWith('.json')) {
    final a = json.decode(s) as List;
    return a.map<RowRec>((e){
      final m = e as Map;
      return RowRec(m['timestamp'] as int, (m['symbol']??'').toString(), (m['y_true'] as num).toInt(), (m['p_raw'] as num).toDouble());
    }).toList();
  } else {
    // very simple CSV: timestamp,symbol,y_true,p_raw
    final lines = s.split(RegExp(r'\r?\n')).where((l)=>l.trim().isNotEmpty).toList();
    final out = <RowRec>[];
    for (final l in lines.skip(1)) {
      final parts = l.split(',');
      out.add(RowRec(int.parse(parts[0]), parts[1], int.parse(parts[2]), double.parse(parts[3])));
    }
    return out;
  }
}

Calibrator _fitPlatt(List<RowRec> train, {double l2 = 0.0}) {
  // Simple logistic regression with fixed iterations (not optimized for speed)
  double a = 0.0, b = 0.0; final lr = 0.1; final iters = 200;
  double sig(double z) => 1.0/(1.0+math.exp(-z));
  for (var t=0; t<iters; t++) {
    double ga=0.0, gb=0.0;
    for (final r in train) { final z = a*r.p + b; final yhat = sig(z); final err = yhat - r.y; ga += err * r.p; gb += err; }
    // L2 regularization (ridge)
    ga += l2 * a; gb += l2 * b;
    a -= lr * ga / train.length; b -= lr * gb / train.length;
  }
  return PlattCalibrator(a,b);
}

Calibrator _fitIsotonic(List<RowRec> train, {int bins=15, int minPerBin=0}) {
  // Pool adjacent violators on binned data (simplified)
  final p = train.map((e)=>e.p).toList();
  final y = train.map((e)=>e.y).toList();
  var rb = reliabilityBins(p, y, bins: bins);
  // Merge underpopulated bins
  if (minPerBin > 0) {
    final merged = <ReliabilityBin>[];
    ReliabilityBin? cur;
    for (final b in rb) {
      if (cur == null) { cur = b; continue; }
      if (cur.n < minPerBin) {
        final totalN = cur.n + b.n;
        final mp = (cur.meanPred*cur.n + b.meanPred*b.n) / (totalN);
        final mt = (cur.meanTrue*cur.n + b.meanTrue*b.n) / (totalN);
        cur = ReliabilityBin(cur.lo, b.hi, totalN, mp, mt);
      } else {
        merged.add(cur); cur = b;
      }
    }
    if (cur != null) merged.add(cur);
    rb = merged;
  }
  final xs = <double>[]; final ys = <double>[];
  for (final b in rb) { xs.add(((b.lo+b.hi)/2.0).clamp(0.0,1.0)); ys.add(b.meanTrue.clamp(0.0,1.0)); }
  // Ensure monotonicity by simple smoothing pass
  for (var i=1;i<ys.length;i++){ if (ys[i] < ys[i-1]) ys[i] = ys[i-1]; }
  return IsotonicCalibrator(xs, ys);
}

Map<String, dynamic> _paramsOf(Calibrator c) {
  if (c is PlattCalibrator) return {'A': c.a, 'B': c.b};
  if (c is IsotonicCalibrator) return {'x': c.xs, 'y': c.ys};
  return {};
}

Future<String> _gitSha() async {
  try {
    final res = await Process.run('git', ['rev-parse', 'HEAD']);
    if (res.exitCode == 0) return (res.stdout as String).trim();
  } catch (_) {}
  return '';
}


