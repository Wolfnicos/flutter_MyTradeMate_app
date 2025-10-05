import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/settings_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'change_password_screen.dart';
import 'package:local_auth/local_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _paperTrading = true;
  bool _twoFA = false;
  bool _biometric = false;

  bool _darkMode = false; // persisted preference only (theme applied on next app init)
  String? _name;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final env = sp.getString('binance.env') ?? 'testnet';
    setState(() {
      _paperTrading = env == 'testnet';
      _twoFA = sp.getBool('auth.2fa') ?? false;
      _biometric = sp.getBool('security.biometric') ?? false;
      _darkMode = sp.getBool('app.dark') ?? false;
      final lang = sp.getString('app.lang') ?? 'en';
      _lang = lang == 'ro' ? 'Română' : 'English';
      _name = sp.getString('profile.name') ?? 'Trader';
      _email = sp.getString('profile.email') ?? 'you@mytrademate.app';
    });
  }

  Future<void> _setPaperTrading(bool v) async {
    setState(() => _paperTrading = v);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('binance.env', v ? 'testnet' : 'live');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(v ? 'Paper Trading (Testnet) enabled' : 'Live trading mode selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 30),

            Text('Security & Privacy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SettingsTile(icon: Icons.lock_outline, title: 'Change Password', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
            }),
            SettingsSwitchTile(icon: Icons.security, title: '2FA Authentication', value: _twoFA, onChanged: _toggle2FA),
            SettingsSwitchTile(icon: Icons.fingerprint, title: 'Biometric Lock (Face ID)', value: _biometric, onChanged: _toggleBiometric),
            const SizedBox(height: 30),

            Text('App Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SettingsTile(icon: Icons.notifications_none, title: 'Notification Preferences', onTap: () {}),
            SettingsTile(icon: Icons.language, title: 'Language (${_langLabel()})', onTap: _pickLanguage),
            SettingsSwitchTile(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              value: _darkMode,
              onChanged: (val) async {
                final sp = await SharedPreferences.getInstance();
                await sp.setBool('app.dark', val);
                if (!mounted) return;
                setState(() => _darkMode = val);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme updated. Will fully apply on next app start.')),
                );
              },
            ),
            const SizedBox(height: 30),

            Text('Trading Backend', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SettingsTile(icon: Icons.api, title: 'Binance API & Testnet Setup', onTap: () {
              _showBinanceApiSetupModal(context);
            }),
            SettingsSwitchTile(icon: Icons.paid, title: 'Paper Trading Mode (Testnet)', value: _paperTrading, onChanged: (val) {
              _setPaperTrading(val);
            }),
            const SizedBox(height: 30),

            Text('Support & Legal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SettingsTile(icon: Icons.help_outline, title: 'Help Center', onTap: _openHelp),
            SettingsTile(icon: Icons.gavel, title: 'Terms & Conditions', onTap: _openTerms),
            const SizedBox(height: 40),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final sp = await SharedPreferences.getInstance();
                  await sp.remove('session.jwt');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
                  // TODO: Navigator.pushReplacement to Login when available
                },
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Colors.indigoAccent,
          child: Icon(Icons.person, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(_name ?? 'Trader', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(_email ?? 'you@mytrademate.app', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: Theme.of(context).colorScheme.secondary, size: 18),
            const SizedBox(width: 5),
            Text('Verified Account', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ],
        ),
      ],
    );
  }

  

  Future<void> _showBinanceApiSetupModal(BuildContext context) async {
    final sp = await SharedPreferences.getInstance();
    final keyCtrl = TextEditingController(text: sp.getString('binance.apiKey') ?? '');
    final secCtrl = TextEditingController(text: sp.getString('binance.secret') ?? '');
    String env = sp.getString('binance.env') ?? 'testnet';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String envState = env; // local editable copy
        return StatefulBuilder(
          builder: (bottomCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Binance API Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: secCtrl, decoration: const InputDecoration(labelText: 'Secret', border: OutlineInputBorder()), obscureText: true),
                  const SizedBox(height: 12),
                  Row(children: [
                    FilterChip(
                      label: const Text('Testnet'),
                      selected: envState == 'testnet',
                      onSelected: (_) => setModalState(() { envState = 'testnet'; }),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Live'),
                      selected: envState == 'live',
                      onSelected: (_) => setModalState(() { envState = 'live'; }),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        // Basic validation: if live is chosen, require keys
                        if (envState == 'live' && (keyCtrl.text.trim().isEmpty || secCtrl.text.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API Key and Secret are required for Live mode.')),
                          );
                          return;
                        }
                        await sp.setString('binance.apiKey', keyCtrl.text.trim());
                        await sp.setString('binance.secret', secCtrl.text.trim());
                        await sp.setString('binance.env', envState);
                        if (mounted) {
                          setState(() => _paperTrading = envState == 'testnet');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved. Using ${envState == 'testnet' ? 'Testnet' : 'Live'} backend.')),
                          );
                        }
                      },
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openHelp() => _launchUrl('https://support.binance.com');
  void _openTerms() => _launchUrl('https://www.binance.com/en/terms');
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  Future<void> _toggle2FA(bool enable) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('auth.2fa', enable);
    if (!mounted) return;
    setState(() => _twoFA = enable);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enable ? '2FA enabled' : '2FA disabled')));
  }

  Future<void> _toggleBiometric(bool enable) async {
    final sp = await SharedPreferences.getInstance();
    try {
      if (enable) {
        final auth = LocalAuthentication();
        final supported = await auth.isDeviceSupported();
        final canCheck = await auth.canCheckBiometrics;
        if (!supported || !canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics not available on this device.')));
          }
          return;
        }
        final ok = await auth.authenticate(
          localizedReason: 'Enable biometric lock for app start',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!ok) return;
      }
      await sp.setBool('security.biometric', enable);
      if (!mounted) return;
      setState(() => _biometric = enable);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enable ? 'Biometric lock enabled' : 'Biometric lock disabled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric error: $e')));
    }
  }

  String _langLabel() {
    // Read cached label from SP synchronously via late state? We fetch once here async fallback
    // For simplicity, we read from SharedPreferences in _pickLanguage and update state label.
    return _lang ?? 'English';
  }

  String? _lang;

  Future<void> _pickLanguage() async {
    final sp = await SharedPreferences.getInstance();
    final current = sp.getString('app.lang') ?? 'en';
    String selected = current;
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose language', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: 'en',
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v ?? 'en'),
                title: const Text('English'),
              ),
              RadioListTile<String>(
                value: 'ro',
                groupValue: selected,
                onChanged: (v) => setState(() => selected = v ?? 'ro'),
                title: const Text('Română'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await sp.setString('app.lang', selected);
                    if (mounted) {
                      setState(() => _lang = selected == 'ro' ? 'Română' : 'English');
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Language set to ${selected == 'ro' ? 'Română' : 'English'}')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
