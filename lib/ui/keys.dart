import 'package:flutter/widgets.dart';

class AppKeys {
  AppKeys._();

  // Settings
  static const settingsApiKeyField = Key('settings.apiKey');
  static const settingsSecretField = Key('settings.secret');
  static const settingsEnvDropdown = Key('settings.env');
  static const settingsQuoteSlider = Key('settings.quote');
  static const settingsTestConnection = Key('settings.testConnection');
  static const settingsSave = Key('settings.save');
  static const settingsSendDiagnostics = Key('settings.sendDiagnostics');

  // MarketDetails
  static const marketReload = Key('market.reload');
  static const marketPriceStreamStatus = Key('market.priceStreamStatus');
  static const marketLiveRegion = Key('market.liveRegion');

  // Trading CTA & confirm sheet
  static const tradePlace = Key('trade.cta.place');
  static const confirmSheet = Key('trade.confirm.sheet');
  static const confirmPlace = Key('trade.confirm.place');
  static const undoTrade = Key('trade.undo');
}


