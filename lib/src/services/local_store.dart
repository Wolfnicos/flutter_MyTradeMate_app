import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  final String? apiKey;
  final String? apiSecret;
  final bool testnet;
  final double fixedQuote;
  bool get hasKeys =>
      (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);

  const AppConfig(
      {this.apiKey,
      this.apiSecret,
      required this.testnet,
      required this.fixedQuote});
}

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();

  Future<AppConfig> getConfig() async {
    final sp = await SharedPreferences.getInstance();
    return AppConfig(
      apiKey: sp.getString('apiKey'),
      apiSecret: sp.getString('apiSecret'),
      testnet: sp.getBool('testnet') ?? true,
      fixedQuote: sp.getDouble('fixedQuote') ?? 50,
    );
  }

  Future<void> saveConfig({
    String? apiKey,
    String? apiSecret,
    required bool testnet,
    required double fixedQuote,
  }) async {
    final sp = await SharedPreferences.getInstance();
    if (apiKey == null) {
      await sp.remove('apiKey');
    } else {
      await sp.setString('apiKey', apiKey);
    }
    if (apiSecret == null) {
      await sp.remove('apiSecret');
    } else {
      await sp.setString('apiSecret', apiSecret);
    }
    await sp.setBool('testnet', testnet);
    await sp.setDouble('fixedQuote', fixedQuote);
  }
}


