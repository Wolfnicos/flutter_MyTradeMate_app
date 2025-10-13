import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mytrademate/ai/ai_locator.dart';
import 'package:mytrademate/ai/entities.dart';

class SignalTraceRow {
  final double tsConf, tsRet, tsVol;
  final double visConf, visRet;
  final List<double> clfProbs; // [buy, hold, sell]
  final double ensConf, ensRet;
  final String ensAction;
  final String? gateReason;
  final String backtesterAction;
  final double open, close;
  final DateTime time;
  SignalTraceRow({
    required this.tsConf,
    required this.tsRet,
    required this.tsVol,
    required this.visConf,
    required this.visRet,
    required this.clfProbs,
    required this.ensConf,
    required this.ensRet,
    required this.ensAction,
    required this.gateReason,
    required this.backtesterAction,
    required this.open,
    required this.close,
    required this.time,
  });

  List<String> toCsv() => [
        tsConf.toStringAsFixed(6),
        tsRet.toStringAsFixed(8),
        tsVol.toStringAsFixed(6),
        visConf.toStringAsFixed(6),
        visRet.toStringAsFixed(8),
        clfProbs[0].toStringAsFixed(6),
        clfProbs[2].toStringAsFixed(6),
        clfProbs[1].toStringAsFixed(6),
        ensConf.toStringAsFixed(6),
        ensRet.toStringAsFixed(8),
        ensAction,
        gateReason ?? '',
        backtesterAction,
        open.toStringAsFixed(2),
        close.toStringAsFixed(2),
        time.toIso8601String(),
      ];
}

Future<void> traceSignals({
  required String symbol,
  required String interval,
  required List<Candle> candles,
  required StrategySettings settings,
  int lookback = 96,
  String outCsvPath = 'trace_signals.csv',
  bool dryRun = true,
}) async {
  final csv = StringBuffer();
  csv.writeln('ts_conf,ts_ret,ts_vol,vis_conf,vis_ret,clf_buy_p,clf_sell_p,clf_hold_p,ensemble_conf,ensemble_ret,ensemble_action,gate_reason,backtester_action,price_open,price_close,time');

  // Prepare AI
  if (!AILocator.I.isInitialized) {
    await AILocator.I.init();
  }
  final repo = AILocator.I.repo;

  // Minimal backtester shell to get decisions
  // backtester not needed directly for tracing decisions

  int mismatch = 0;
  int trades = 0;

  for (int i = lookback; i < candles.length; i++) {
    final window = candles.sublist(i - lookback, i);
    final cur = candles[i];

    final pred = await AILocator.I.engine.predict(symbol, window);
    if (pred == null) continue;

    final tsConf = pred.confidence();
    final tsRet = pred.expReturn;
    final tsVol = pred.annVol;
    final clfProbs = [pred.pBuy, pred.pHold, pred.pSell];

    // repo ensemble (will also include Vision if enabled)
    final repoPred = await repo.getOrFetch(symbol: symbol, interval: interval, limit: lookback + 10);
    if (repoPred == null) continue;
    final ensConf = repoPred.confidence();
    final ensRet = repoPred.expReturn;
    final ensAction = AILocator.I.decide(repoPred);

    double visConf = 0.0, visRet = 0.0;
    if (repoPred.visionProbs != null) {
      final v = repoPred.visionProbs!;
      final vMax = v.reduce((a,b) => a>b? a:b);
      visConf = vMax;
      visRet = ensRet; // no separate vis ret currently
    }

    // Gate reason similar to backtester thresholds
    String? gateReason;
    if (!tsRet.isFinite) gateReason = 'bad_expReturn';
    else if (!(tsVol.isFinite) || tsVol <= 0.0) gateReason = 'bad_vol';
    else if (ensConf < settings.confThresh) gateReason = 'low_conf';

    // Backtester action (dry run means ignore SL/TP/fees and just decide)
    String btAction;
    if (gateReason != null) {
      btAction = 'HOLD';
    } else {
      btAction = ensAction;
      if (btAction != 'HOLD') trades++;
    }

    final row = SignalTraceRow(
      tsConf: tsConf,
      tsRet: tsRet,
      tsVol: tsVol,
      visConf: visConf,
      visRet: visRet,
      clfProbs: clfProbs,
      ensConf: ensConf,
      ensRet: ensRet,
      ensAction: ensAction,
      gateReason: gateReason,
      backtesterAction: btAction,
      open: cur.open,
      close: cur.close,
      time: cur.time,
    );
    csv.writeln(row.toCsv().join(','));

    if (ensAction != btAction && gateReason == null) mismatch++;
  }

  final file = File(outCsvPath);
  await file.writeAsString(csv.toString());
  if (kDebugMode) {
    debugPrint('[TRACE] Wrote ${candles.length - lookback} rows to ${file.path}');
    debugPrint('[TRACE] trades=$trades mismatch_count=$mismatch');
  }
}
