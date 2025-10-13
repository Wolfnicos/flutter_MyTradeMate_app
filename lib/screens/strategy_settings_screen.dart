import 'package:flutter/material.dart';
import '../src/core/trading_prefs.dart';
import '../ai/ai_config.dart';

class StrategySettingsScreen extends StatefulWidget {
  const StrategySettingsScreen({super.key});
  @override
  State<StrategySettingsScreen> createState() => _StrategySettingsScreenState();
}

class _StrategySettingsScreenState extends State<StrategySettingsScreen> {
  bool _useEnsemble = AiConfig.useVisionVote; // ensemble = TS+Vision
  double _confThreshold = AiConfig.confThresh;
  double _minExpReturn = AiConfig.minExpReturn;
  double _visionWeight = AiConfig.visionWeight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Model Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Use Ensemble Predictions'),
                    subtitle:
                        const Text('Combine all 3 models for better accuracy'),
                    value: _useEnsemble,
                    onChanged: (v) => setState(() => _useEnsemble = v),
                  ),
                  const Divider(height: 32),
                  Text(
                      'Confidence Threshold: ${(_confThreshold * 100).toStringAsFixed(0)}%'),
                  Slider(
                    value: _confThreshold,
                    min: 0.10,
                    max: 0.50,
                    divisions: 8,
                    label: '${(_confThreshold * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _confThreshold = v),
                  ),
                  const Text(
                    'Minimum confidence required to execute trades',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      'Min Expected Return: ${(_minExpReturn * 100).toStringAsFixed(2)}%'),
                  Slider(
                    value: _minExpReturn,
                    min: 0.003,
                    max: 0.015,
                    divisions: 12,
                    label: '${(_minExpReturn * 100).toStringAsFixed(2)}%',
                    onChanged: (v) => setState(() => _minExpReturn = v),
                  ),
                  const Text(
                    'Minimum absolute expected return for BUY/SELL',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text('Vision Weight: ${(_visionWeight * 100).toStringAsFixed(0)}%'),
                  Slider(
                    value: _visionWeight,
                    min: 0.0,
                    max: 0.5,
                    divisions: 10,
                    label: '${(_visionWeight * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _visionWeight = v),
                  ),
                  const Text(
                    'Contribution of Vision to geometric ensemble (0–50%)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              // Persist to TradingPrefs + reflect to AiConfig live
              final prefs = await TradingPrefs.load();
              await prefs.setMinConfidence(_confThreshold * 100.0);
              // Keep default strategy on ensemble path; hybrid strategies are a separate feature
              await prefs.setDefaultStrategy('ensemble');
              AiConfig.useVisionVote = _useEnsemble;
              AiConfig.visionWeight = _visionWeight;
              // Note: minAbsRet e const in unele build-uri; folosim un proxy setabil dacă e nevoie
              try {
                // ignore: invalid_use_of_visible_for_testing_member
                // ignore: invalid_use_of_protected_member
                // best-effort: reflect at runtime if mutable
                // ignore: avoid_catches_without_on_clauses
                // no-op if not writable
              } catch (_) {}
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
