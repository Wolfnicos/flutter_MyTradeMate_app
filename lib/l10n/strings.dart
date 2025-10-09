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
  // Simple locale detection (EN by default, RO if device locale is ro)
  static bool _isRomanian = false;
  
  static void setLocale(String locale) {
    _isRomanian = locale.toLowerCase().startsWith('ro');
  }
  
  // General
  static String get signalWhy => _isRomanian ? 'De ce acest semnal?' : 'Why this signal?';
  static String get paperBadge => 'PAPER / TESTNET';
  static String get modelCardOpen => _isRomanian ? 'Card model →' : 'Model card →';
  static String get modelCardOpenLabel => _isRomanian ? 'Deschide card model' : 'Open model card';
  static String get modelCardOpenHint => _isRomanian ? 'Deschide cardul modelului în browser' : 'Opens the model card in your browser';
  static String get modelCardOpenError => _isRomanian ? 'Nu s-a putut deschide cardul modelului' : 'Could not open model card';

  // Toggles
  static String get showUncertaintyNote => _isRomanian ? 'Arată nota de incertitudine' : 'Show uncertainty note';
  static String get showDataGapsNote => _isRomanian ? 'Arată nota despre goluri de date' : 'Show data gaps note';
  
  // AI Helper Screen
  static String get aiHelperTitle => _isRomanian ? 'Asistent AI Trading' : 'AI Trading Assistant';
  static String get aiHelperWelcome => _isRomanian ? 'Asistent Inteligent Trading Crypto' : 'Intelligent Crypto Trading Assistant';
  static String get aiHelperDescription => _isRomanian 
      ? 'Asistent inteligent pentru trading crypto cu date LIVE de piață și predicții AI în timp real.'
      : 'Intelligent assistant for crypto trading with LIVE market data and real-time AI predictions.';
  static String get aiLiveData => _isRomanian ? 'Date live de pe Binance' : 'Live data from Binance';
  static String get aiRealTimePredictions => _isRomanian ? 'Predicții AI în timp real' : 'Real-time AI predictions';
  static String get aiMultiCurrency => _isRomanian ? 'Suport USD/USDT/EUR' : 'USD/USDT/EUR support';
  static String get aiPremiumCrypto => _isRomanian ? '5 Crypto Premium' : '5 Premium Crypto';
  static String get selectFiatCurrency => _isRomanian ? 'Selectează Moneda Fiat' : 'Select Fiat Currency';
  static String get premiumCryptoLive => _isRomanian ? '5 Crypto Premium (Date LIVE)' : '5 Premium Crypto (LIVE Data)';
  static String get detailedAnalysis => _isRomanian ? 'Analiză Detaliată' : 'Detailed Analysis';
  static String get aiPredictionLive => _isRomanian ? 'Predicție AI (LIVE)' : 'AI Prediction (LIVE)';
  static String get marketDataLive => _isRomanian ? 'Date Piață (LIVE)' : 'Market Data (LIVE)';
  static String get action => _isRomanian ? 'Acțiune' : 'Action';
  static String get confidence => _isRomanian ? 'Încredere' : 'Confidence';
  static String get targetPrice => _isRomanian ? 'Țintă Preț' : 'Target Price';
  static String get volatility => _isRomanian ? 'Volatilitate' : 'Volatility';
  static String get probabilityUp => _isRomanian ? 'Probabilitate Creștere' : 'Probability Up';
  static String get estimatedReturn => _isRomanian ? 'Return Estimat' : 'Estimated Return';
  static String get price => _isRomanian ? 'Preț' : 'Price';
  static String get change24h => _isRomanian ? 'Schimbare 24h' : '24h Change';
  static String get volume24h => _isRomanian ? 'Volum 24h' : '24h Volume';
  static String get high24h => _isRomanian ? 'High 24h' : '24h High';
  static String get low24h => _isRomanian ? 'Low 24h' : '24h Low';
  static String get howItWorks => _isRomanian ? 'Cum funcționează' : 'How it works';
  static String get liveDataTitle => _isRomanian ? 'Date LIVE' : 'LIVE Data';
  static String get liveDataDesc => _isRomanian 
      ? 'Toate prețurile și datele sunt preluate în timp real de pe Binance. Nu sunt simulate!'
      : 'All prices and data are fetched in real-time from Binance. Not simulated!';
  static String get aiPredictionsTitle => _isRomanian ? 'Predicții AI' : 'AI Predictions';
  static String get aiPredictionsDesc => _isRomanian 
      ? 'Modelele AI analizează date istorice și identifică pattern-uri pentru predicții.'
      : 'AI models analyze historical data and identify patterns for predictions.';
  static String get quoteCurrencyTitle => _isRomanian ? 'Quote Currency' : 'Quote Currency';
  static String get quoteCurrencyDesc => _isRomanian 
      ? 'Poți alege între USDT (stablecoin), USD sau EUR pentru a vedea prețurile.'
      : 'You can choose between USDT (stablecoin), USD or EUR to view prices.';
  static String get disclaimerAITitle => _isRomanian ? 'Disclaimer' : 'Disclaimer';
  static String get disclaimerAIDesc => _isRomanian 
      ? 'Nu oferim sfaturi financiare. Aceste predicții sunt doar orientative!'
      : 'We do not provide financial advice. These predictions are for guidance only!';
  static String get noPrediction => _isRomanian 
      ? 'Nicio predicție (AI indisponibil sau pair neacceptat).'
      : 'No prediction (AI unavailable or pair not supported).';
  static String get aiButtonLive => _isRomanian 
      ? '🤖 Asistent AI Trading (LIVE)'
      : '🤖 AI Trading Assistant (LIVE)';
}

// Note: legacy extension kept if needed; prefer S static getters above
