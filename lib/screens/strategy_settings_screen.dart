import 'package:flutter/material.dart';

class StrategySettingsScreen extends StatefulWidget {
  const StrategySettingsScreen({super.key});
  @override
  State<StrategySettingsScreen> createState() => _StrategySettingsScreenState();
}

class _StrategySettingsScreenState extends State<StrategySettingsScreen> {
  bool _useEnsemble = true;
  double _confThreshold = 0.20;

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
                    subtitle: const Text('Combine all 3 models for better accuracy'),
                    value: _useEnsemble,
                    onChanged: (v) => setState(() => _useEnsemble = v),
                  ),
                  const Divider(height: 32),
                  Text('Confidence Threshold: ${(_confThreshold * 100).toStringAsFixed(0)}%'),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved!')),
              );
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


