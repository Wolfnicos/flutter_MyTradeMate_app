import 'dart:async';
import 'package:flutter/material.dart';
import 'ai/predictors/vision_predictor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VisionProbeApp());
}

class VisionProbeApp extends StatefulWidget {
  const VisionProbeApp({super.key});
  @override
  State<VisionProbeApp> createState() => _VisionProbeAppState();
}

class _VisionProbeAppState extends State<VisionProbeApp> {
  final _vp = VisionPredictor();
  List<double>? _probs;
  String _status = 'loading...';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final p = await _vp.predictFromAsset('assets/images/chart_probe.png');
      setState(() {
        _probs = p;
        _status = 'ok';
      });
      // ignore: avoid_print
      print(
          'VISION probs [BUY,HOLD,SELL]: ${p.map((e) => e.toStringAsFixed(3)).toList()}');
    } catch (e) {
      setState(() {
        _status = 'error: $e';
      });
    }
  }

  @override
  void dispose() {
    _vp.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final probsText = _probs == null
        ? _status
        : 'BUY ${_probs![0].toStringAsFixed(3)}  |  HOLD ${_probs![1].toStringAsFixed(3)}  |  SELL ${_probs![2].toStringAsFixed(3)}';
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Vision Probe')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 300,
                height: 300,
                child: Image(
                  image: AssetImage('assets/images/chart_probe.png'),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(probsText, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
