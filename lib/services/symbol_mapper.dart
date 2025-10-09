/// SymbolMapper - Normalizează simboluri între UI și feed
/// UI poate arăta EUR, dar feed-ul Binance suportă doar USDT
class SymbolMapper {
  /// Map UI symbol (BTC/EUR, BTCEUR, etc.) → feed symbol (BTCUSDT)
  /// 
  /// Examples:
  /// - 'BTC/USDT' → 'BTCUSDT'
  /// - 'BTCEUR' → 'BTCUSDT' (dacă quote='USDT')
  /// - 'ETH/USD' → 'ETHUSDT' (dacă quote='USDT')
  static String mapUiToFeed(String uiSymbol, {String quote = 'USDT'}) {
    // Remove slashes și uppercase
    final normalized = uiSymbol.replaceAll('/', '').toUpperCase();
    
    // Extract base (BTC, ETH, etc.)
    final base = normalized.replaceAll(RegExp(r'(USDT|USD|EUR|BUSD)$'), '');
    
    // Return în format Binance cu quote dorit
    return '$base$quote';
  }

  /// Convert feed symbol → UI display symbol
  /// 
  /// Examples:
  /// - 'BTCUSDT' + displayQuote='EUR' → 'BTC/EUR'
  /// - 'ETHUSDT' + displayQuote='USD' → 'ETH/USD'
  static String feedToUi(String feedSymbol, {String displayQuote = 'USDT'}) {
    final normalized = feedSymbol.toUpperCase().replaceAll(RegExp(r'(USDT|USD|EUR|BUSD)$'), '');
    return '$normalized/$displayQuote';
  }

  /// Extract base symbol (BTC, ETH, etc.)
  static String getBase(String symbol) {
    return symbol
        .replaceAll('/', '')
        .toUpperCase()
        .replaceAll(RegExp(r'(USDT|USD|EUR|BUSD)$'), '');
  }

  /// Extract quote symbol (USDT, USD, EUR, etc.)
  static String getQuote(String symbol) {
    final match = RegExp(r'(USDT|USD|EUR|BUSD)$').firstMatch(symbol.toUpperCase());
    return match?.group(1) ?? 'USDT';
  }
}


