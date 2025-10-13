import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../src/core/trading_prefs.dart';
import '../services/dio_binance_client.dart';
import '../core/logging.dart';
import '../core/diagnostics.dart';
import '../l10n/strings.dart';
import '../ui/keys.dart';
import '../ui/debug/observability_chip.dart';
import 'package:mytrademate/widgets/premium_widgets.dart';
// Sort keys removed for broader Flutter version compatibility

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
  bool _telemetryOptIn = false;
  bool _paperMode = true;

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
      _paperMode = true; // default to paper/testnet for safety
      // Load telemetry opt-in
      // ignore: discarded_futures
      p.getTelemetryOptIn().then((v) {
        if (mounted) setState(() => _telemetryOptIn = v);
      });
      _ready = true;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    // basic validations
    if ((_apiKey.isEmpty && _secret.isNotEmpty) ||
        (_apiKey.isNotEmpty && _secret.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please provide BOTH API Key and Secret, or leave both empty.')),
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
    // Bonus UX: when enabling paper mode, clear balances hint and toast
    if (_useTestnet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Paper mode enabled – live balances hidden')),
      );
    } else if ((_apiKey.isEmpty || _secret.isEmpty) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add API key in Settings to load balances')),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _testConnection() async {
    try {
      AppLogger.instance.info('settings.testConnection.start');
      final client = await DioBinanceClient.createFromPrefs();
      final ok = await client.testConnection();
      AppLogger.instance
          .info('settings.testConnection.done', context: {'ok': ok});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Connection OK' : 'Connection failed')),
      );
    } catch (e) {
      AppLogger.instance.warn('settings.testConnection.error',
          context: {'error': e.toString()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final inputDecoration = (String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kText2),
          filled: true,
          fillColor: Colors.white.withOpacity(0.04),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kHold, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    return Scaffold(
      appBar: AppBar(title: Text(S.settingsTitle), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              Text(S.settingsKeysHeader,
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ModernCard(
                hasGlow: false,
                child: ListTile(
                  key: const Key('settingsDisclaimerTile'),
                  leading: const Icon(Icons.policy_outlined, color: kHold),
                  title: Text(S.settingsDisclaimerTitle,
                      style: const TextStyle(color: kText)),
                  subtitle: Text(
                    S.settingsDisclaimerShort,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kText2),
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(S.disclaimerTitle),
                      content: Text(S.disclaimerBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                              MaterialLocalizations.of(context).okButtonLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _apiKey,
                decoration: inputDecoration(S.apiKeyLabel).copyWith(
                  suffixIcon: Semantics(
                    label: S.a11yPasteKey,
                    button: true,
                    child: IconButton(
                      tooltip: S.paste,
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        final text = data?.text ?? '';
                        if (text.isNotEmpty) {
                          setState(() => _apiKey = text.trim());
                        }
                      },
                    ),
                  ),
                ),
                autofillHints: const [AutofillHints.password],
                onSaved: (v) => _apiKey = v?.trim() ?? '',
                key: AppKeys.settingsApiKeyField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _secret,
                decoration: inputDecoration(S.secretLabel).copyWith(
                  suffixIcon: Semantics(
                    label: S.a11yToggleSecret,
                    button: true,
                    child: IconButton(
                      tooltip: _showSecret ? S.hide : S.show,
                      icon: Icon(_showSecret
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _showSecret = !_showSecret),
                    ),
                  ),
                ),
                obscureText: !_showSecret,
                enableSuggestions: false,
                autocorrect: false,
                onSaved: (v) => _secret = v?.trim() ?? '',
                key: AppKeys.settingsSecretField,
              ),
              const SizedBox(height: 16),
              // Telemetry opt-in toggle (opt-in only)
              ModernCard(
                hasGlow: false,
                child: SwitchListTile(
                  title: const Text('Share anonymous diagnostics', style: TextStyle(color: kText)),
                  subtitle: const Text('Optional. Helps improve stability. No PII or keys.', style: TextStyle(color: kText2)),
                  value: _telemetryOptIn,
                  onChanged: (v) async {
                    setState(() => _telemetryOptIn = v);
                    final prefs = await TradingPrefs.load();
                    await prefs.setTelemetryOptIn(v);
                  },
                ),
              ),
              const SizedBox(height: 8),
              ModernCard(
                hasGlow: false,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Text(S.environment,
                          softWrap: true, overflow: TextOverflow.fade, style: const TextStyle(color: kText)),
                      const SizedBox(width: 12),
                      DropdownButton<bool>(
                        value: _useTestnet,
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Testnet (Paper)')),
                          DropdownMenuItem(value: false, child: Text('Live')),
                        ],
                        onChanged: (v) async {
                          final newVal = v ?? true;
                          setState(() => _useTestnet = newVal);
                          final prefs = await TradingPrefs.load();
                          await prefs.save(env: newVal ? TradeEnv.testnet : TradeEnv.live);
                          if (!mounted) return;
                          if (newVal) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Paper mode enabled – live balances hidden')),
                            );
                          } else if ((_apiKey.isEmpty || _secret.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Add API key to load balances')),
                            );
                          }
                        },
                        key: AppKeys.settingsEnvDropdown,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _useTestnet ? S.envHelpTestnet : S.envHelpLive,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kText2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('${S.fixedQuote} ${_quote.round()}', style: const TextStyle(color: kText2)),
              Slider(
                min: 10,
                max: 2000,
                divisions: 199,
                value: _quote,
                label: _quote.round().toString(),
                onChanged: (v) => setState(() => _quote = v),
                key: AppKeys.settingsQuoteSlider,
              ),
              const SizedBox(height: 8),
              const ObservabilityChip(maxItems: 3),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Semantics(
                    container: true,
                    child: ElevatedButton.icon(
                      onPressed: _testConnection,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(S.testConnection),
                      key: AppKeys.settingsTestConnection,
                    ),
                  ),
                  Semantics(
                    container: true,
                    child: FilledButton(
                      onPressed: _ready
                          ? () async {
                              await _save();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(S.settingsSaved)),
                              );
                            }
                          : null,
                      key: AppKeys.settingsSave,
                      child: Text(S.save),
                    ),
                  ),
                  Semantics(
                    label: S.diagnosticBundle,
                    button: true,
                    container: true,
                    child: Tooltip(
                      message: S.diagnosticBundle,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final path = await createDiagnosticBundle();
                          if (!mounted) return;
                          final msg = path != null
                              ? 'Diagnostic bundle created: $path'
                              : 'Failed to create diagnostic bundle';
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        },
                        icon: const Icon(Icons.bug_report),
                        label: Text(S.diagnosticBundle),
                        key: AppKeys.settingsSendDiagnostics,
                      ),
                    ),
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
