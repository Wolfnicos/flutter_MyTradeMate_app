import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import '../src/core/trading_prefs.dart';
import '../services/dio_binance_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  String _apiKey = '';
  String _secret = '';
  bool _useTestnet = true;
  double _quote = 50;
  bool _ready = false;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await TradingPrefs.load();
    setState(() {
      _apiKey = p.apiKey ?? '';
      _secret = p.apiSecret ?? '';
      _useTestnet = p.env == TradeEnv.testnet;
      _quote = p.fixedQuote;
      _ready = true;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    // basic validations
    if ((_apiKey.isEmpty && _secret.isNotEmpty) || (_apiKey.isNotEmpty && _secret.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide BOTH API Key and Secret, or leave both empty.')),
      );
      return;
    }
    if (_quote < 10) {
      _quote = 10;
    }
    final prefs = await TradingPrefs.load();
    await prefs.save(
      apiKey: _apiKey.trim(),
      apiSecret: _secret.trim(),
      env: _useTestnet ? TradeEnv.testnet : TradeEnv.live,
      fixedQuote: _quote,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _testConnection() async {
    try {
      final client = await DioBinanceClient.createFromPrefs();
      final ok = await client.testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Connection OK' : 'Connection failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              const Text('Binance Keys (Testnet/Live)'),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _apiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text ?? '';
                      if (text.isNotEmpty) {
                        setState(() => _apiKey = text.trim());
                      }
                    },
                  ),
                ),
                autofillHints: const [AutofillHints.password],
                onSaved: (v) => _apiKey = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _secret,
                decoration: InputDecoration(
                  labelText: 'Secret',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _showSecret ? 'Hide' : 'Show',
                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                  ),
                ),
                obscureText: !_showSecret,
                enableSuggestions: false,
                autocorrect: false,
                onSaved: (v) => _secret = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Environment:'),
                  const SizedBox(width: 12),
                  DropdownButton<bool>(
                    value: _useTestnet,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Testnet')),
                      DropdownMenuItem(value: false, child: Text('Live')),
                    ],
                    onChanged: (v) => setState(() => _useTestnet = v ?? true),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _useTestnet
                          ? 'Orders/prices use Binance TESTNET endpoints.'
                          : 'Make sure API key has trading permission.',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Fixed quote (USDT): ${_quote.round()}'),
              Slider(
                min: 10,
                max: 2000,
                divisions: 199,
                value: _quote,
                label: _quote.round().toString(),
                onChanged: (v) => setState(() => _quote = v),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(onPressed: _testConnection, icon: const Icon(Icons.wifi_tethering), label: const Text('Test connection')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _ready ? () async {
                      await _save();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings saved')),
                      );
                    } : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
String? validateApiKeyForTest(String? v) {
  if (v == null || v.trim().isEmpty) return 'API key required';
  if (v.trim().length < 8) return 'API key too short';
  return null;
}

@visibleForTesting
String? validateSecretForTest(String? v) {
  if (v == null || v.trim().isEmpty) return 'API secret required';
  if (v.trim().length < 12) return 'API secret too short';
  return null;
}
