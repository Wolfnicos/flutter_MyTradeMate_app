import 'package:flutter/material.dart';

import '../../backtesting/backtester.dart';
import '../../backtesting/backtest_repository.dart';
import '../../ai/ai_locator.dart';
import '../../services/ohlcv_service.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final _symbolCtrl = TextEditingController(text: 'BTCUSDT');
  String _interval = '5m';
  double _initialCapital = 10000.0;
  bool _running = false;
  String? _lastPathJson;
  String? _lastPathCsv;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backtesting')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _symbolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Symbol (e.g., BTCUSDT)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _interval,
                  items: const [
                    DropdownMenuItem(value: '5m', child: Text('5m')),
                    DropdownMenuItem(value: '15m', child: Text('15m')),
                    DropdownMenuItem(value: '1h', child: Text('1h')),
                  ],
                  onChanged: (v) => setState(() => _interval = v!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Initial Capital (USDT)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _initialCapital.toStringAsFixed(2)),
              onChanged: (v) => _initialCapital = double.tryParse(v) ?? _initialCapital,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Run Backtest'),
            ),
            const SizedBox(height: 12),
            if (_lastPathJson != null || _lastPathCsv != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_lastPathJson != null)
                        Text('JSON: $_lastPathJson', style: const TextStyle(fontSize: 12)),
                      if (_lastPathCsv != null)
                        Text('CSV:  $_lastPathCsv', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final engine = AILocator.I.engine;
      final svc = await OHLCVService.createFromPrefs();
      final bt = Backtester(engine: engine, ohlcv: svc);
      final res = await bt.run(
        symbol: _symbolCtrl.text.trim(),
        interval: _interval,
        initialCapital: _initialCapital,
      );
      final repo = await BacktestRepository.create();
      final jsonF = await repo.saveJson(res);
      final csvF = await repo.saveCsv(res);
      setState(() {
        _lastPathJson = jsonF.path;
        _lastPathCsv = csvF.path;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backtest saved: ${jsonF.path.split('/').last}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backtest failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }
}


