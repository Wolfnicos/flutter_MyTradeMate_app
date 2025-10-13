import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../vision/chart_capture_service.dart';
import '../ai/vision_predictor.dart';
import '../services/ohlcv_service.dart';
import '../ai/ai_config.dart';
import '../services/symbol_mapper.dart';

class VisionDebugScreen extends StatefulWidget {
  const VisionDebugScreen({super.key});
  @override
  State<VisionDebugScreen> createState() => _VisionDebugScreenState();
}

class _VisionDebugScreenState extends State<VisionDebugScreen> {
  Uint8List? _rgb;
  int _w = 0, _h = 0;
  List<double>? _probs;
  String _symbol = 'BTCUSDT';
  String _tf = AiConfig.kInterval;

  @override
  void initState() {
    super.initState();
    _recapture();
  }

  Future<void> _recapture() async {
    try {
      final feed = SymbolMapper.mapUiToFeed(_symbol, quote: AiConfig.kDefaultQuote);
      final svc = await OHLCVService.createFromPrefs();
      final candles = await svc.fetchCandles(feed, interval: _tf, limit: 256, forceQuote: true);
      final cap = await ChartCaptureService.renderCandlesImage(candles: candles, width: 320, height: 200);
      await VisionPredictor.I.ensureLoaded();
      final probs = await VisionPredictor.I.predictProbsRGB(rgbBytes: cap.bytes, width: cap.width, height: cap.height);
      if (!mounted) return;
      setState(() {
        _rgb = cap.bytes;
        _w = cap.width;
        _h = cap.height;
        _probs = probs;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rgb = null;
        _probs = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vision Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: Text('Symbol: $_symbol @ $_tf', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: _recapture, child: const Text('Re-capture')),
            ]),
            const SizedBox(height: 12),
            if (_rgb != null)
              SizedBox(
                width: double.infinity,
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.memory(
                      _rgb!,
                      width: _w.toDouble(),
                      height: _h.toDouble(),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            else
              const Text('No capture available'),
            const SizedBox(height: 12),
            if (_probs != null)
              Text('Vision probs: BUY ${_probs![0].toStringAsFixed(2)}  HOLD ${_probs![1].toStringAsFixed(2)}  SELL ${_probs![2].toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}


