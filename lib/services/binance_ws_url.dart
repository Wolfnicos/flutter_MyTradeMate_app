// Unified Binance WebSocket URL builder for miniTicker stream
// Always WSS; no spurious ports or trailing characters on testnet
Uri binanceWsUrl(String symbol, {required bool testnet}) {
  final s = symbol.toLowerCase();
  if (testnet) {
    return Uri(
      scheme: 'wss',
      host: 'testnet.binance.vision',
      path: '/ws/$s@miniTicker',
    );
  }
  return Uri(
    scheme: 'wss',
    host: 'stream.binance.com',
    port: 9443,
    path: '/ws/$s@miniTicker',
  );
}
