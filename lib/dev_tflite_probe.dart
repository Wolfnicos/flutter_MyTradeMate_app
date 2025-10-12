import 'dart:developer';
import 'package:flutter/material.dart';
import 'ai/predictor_tflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _App());
}

class _App extends StatefulWidget {
  const _App({super.key});
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final pred = TFLitePredictor();
      final window = List.generate(64, (_) => List.filled(9, 0.01));
      final out = await pred.predict('BTCUSDT', window, timeframe: '15m');
      setState(() => _status = out == null
          ? 'Interpreter a rulat, dar nu a dat output așteptat (OK pentru dummy)'
          : 'OK: pBuy=${out.pBuy.toStringAsFixed(3)} pHold=${out.pHold.toStringAsFixed(3)} pSell=${out.pSell.toStringAsFixed(3)}');
      log(_status);
    } catch (e, st) {
      setState(() => _status = 'Eroare: $e');
      log('Eroare', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E0E12),
        body: Center(
          child: Text(_status, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
