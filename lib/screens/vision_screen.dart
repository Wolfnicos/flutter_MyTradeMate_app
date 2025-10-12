import 'package:flutter/material.dart';
import '../widgets/premium_widgets.dart';
import '../../ai/predictors/vision_predictor.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});
  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  final _vp = VisionPredictor();
  List<double>? _probs;
  String _status = 'loading...';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final p = await _vp.predictFromAsset('assets/images/chart_probe.png');
      setState(() => _probs = p);
    } catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  void dispose() {
    _vp.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final probs = _probs;
    return Scaffold(
      appBar: AppBar(title: const Text('Vision AI Signal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ModernCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 220,
                child:
                    Image(image: AssetImage('assets/images/chart_probe.png')),
              ),
              const SizedBox(height: 16),
              if (probs == null)
                Text(_status, textAlign: TextAlign.center)
              else
                Text(
                  'BUY ${probs[0].toStringAsFixed(3)}  |  HOLD ${probs[1].toStringAsFixed(3)}  |  SELL ${probs[2].toStringAsFixed(3)}',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
