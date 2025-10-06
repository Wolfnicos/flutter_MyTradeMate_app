class S {
  S._();

  // Settings
  static String get settingsTitle => 'Settings';
  static String get settingsKeysHeader => 'Binance Keys (Testnet/Live)';
  static String get apiKeyLabel => 'API Key';
  static String get secretLabel => 'Secret';
  static String get paste => 'Paste';
  static String get show => 'Show';
  static String get hide => 'Hide';
  static String get environment => 'Environment:';
  static String get testnet => 'Testnet';
  static String get live => 'Live';
  static String get envHelpTestnet => 'Orders/prices use Binance TESTNET endpoints.';
  static String get envHelpLive => 'Make sure API key has trading permission.';
  static String get fixedQuote => 'Fixed quote (USDT):';
  static String get testConnection => 'Test connection';
  static String get save => 'Save';
  static String get settingsSaved => 'Settings saved';
  static String get diagnosticBundle => 'Send diagnostic bundle';
  static String get connectionOk => 'Connection OK';
  static String get connectionFailed => 'Connection failed';
  static String get provideBothKeys => 'Please provide BOTH API Key and Secret, or leave both empty.';
  static String get apiKeyRequired => 'API key required';
  static String get apiKeyTooShort => 'API key too short';
  static String get apiSecretRequired => 'API secret required';
  static String get apiSecretTooShort => 'API secret too short';

  // A11y labels
  static String get a11yPasteKey => 'Paste API key from clipboard';
  static String get a11yToggleSecret => 'Toggle visibility of API secret';
  static String get a11yEnvDropdown => 'Trading environment selector';
  static String get a11yQuoteSlider => 'Fixed quote amount in USDT';
  static String get a11yTestConnection => 'Test connectivity to exchange';
  static String get a11ySaveSettings => 'Save settings';
  static String get a11ySendDiagnostics => 'Create and show path to diagnostic bundle';

  // Market details
  static String get marketRefresh => 'Refresh';
  static String get lastPrice => 'Last price';
  static String get chartNoData => 'No chart data';
  static String get chartErrorPrefix => 'Error loading chart data';
  static String get symbolUnsupportedBanner =>
      'This symbol is not available on the current environment (e.g., Binance Testnet). Chart and orders may be disabled.';
  static String get buy => 'Buy';
  static String get sell => 'Sell';

  // Disclaimer strings
  static String get disclaimerTitle => 'Paper trading only';
  static String get disclaimerBody =>
      'This app performs simulated (paper) trades only. '
      'Nothing here is financial advice. Past performance is not indicative of future results.';
  static String get disclaimerAccept => 'I understand';
  static String get settingsDisclaimerTitle => 'Disclaimer';
  static String get settingsDisclaimerShort =>
      'Paper trading only • Not financial advice';
}

class L10n {
  // General
  static String get signalWhy => 'Why this signal?';
  static String get paperBadge => 'PAPER / TESTNET';
  static String get modelCardOpen => 'Model card →';
  static String get modelCardOpenLabel => 'Open model card';
  static String get modelCardOpenHint => 'Opens the model card in your browser';
  static String get modelCardOpenError => 'Could not open model card';

  // Toggles
  static String get showUncertaintyNote => 'Show uncertainty note';
  static String get showDataGapsNote => 'Show data gaps note';
}

// Note: legacy extension kept if needed; prefer S static getters above
