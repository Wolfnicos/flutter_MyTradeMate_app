## MyTradeMate Architecture

### Scope
End-to-end architecture map and data flow: modules inventory, swimlane from market data to UI, code anchors for each hop, broken links, and per-domain Definition of Done.

## 1) Inventory by Domain

### UI
- Screens (Material):
  - `lib/main.dart` → app boot, `MainNavigator` bottom tabs
  - `lib/screens/dashboard_screen.dart` → live price, AI self-test, charts, assets
  - `lib/screens/market_screen.dart` → multi-symbol live stream list
  - `lib/screens/market_details_screen.dart` → chart + AI + trade buttons
  - `lib/screens/portfolio_screen.dart` → mock holdings, mini chart
  - `lib/screens/profile_screen.dart`
  - `lib/screens/ai_strategies_screen.dart`
  - `lib/screens/trading_modal.dart` → order flow (Market)
  - `lib/screens/settings_screen.dart` → API keys, env, quote size
- Widgets (screens/widgets):
  - `ai_alert_card.dart`, `ai_prediction_card.dart`, `ai_status_card.dart`, `asset_tile.dart`, `settings_tile.dart`
- UI (standalone):
  - `lib/ui/explain_page.dart` (not wired in nav)
- Alternate app shell (unused in main navigator):
  - `lib/src/app/app_scaffold.dart` with `lib/src/features/*` pages

### State
- Local state in widgets (StatefulWidget)
- Persistence:
  - `lib/src/core/trading_prefs.dart` (SharedPreferences for API keys/env/quote)
  - `lib/src/core/order_history.dart` (SharedPreferences for recent orders)
  - `lib/services/settings_store.dart` (SharedPreferences for `AppSettings`) — currently unused

### Market Data
- WebSocket streaming:
  - `lib/services/price_stream.dart` (miniTicker via `web_socket_channel`)
- REST (Binance):
  - `lib/services/dio_binance_client.dart` (Dio-based public/signed endpoints)
  - Alt/legacy (unused): `lib/src/services/binance.dart` (http-based), `lib/src/core/binance_client.dart` (http-based), `lib/services/binance_client.dart` (abstract)

### Trading / Orders
- UI flow: `lib/screens/trading_modal.dart`
- Client: `lib/services/dio_binance_client.dart` → `newMarketOrderQuote`/`newOrderMarketDouble`
- Risk helpers: `clampQuoteToMinNotional` (client helper)
- Rules model: `lib/services/exchange_rules.dart` (not used by current flow)

### Portfolio / PnL
- UI: `lib/screens/portfolio_screen.dart` (mock holdings, price via REST)
- Order storage: `lib/src/core/order_history.dart`
- Account endpoint exists but unused: `DioBinanceClient.account()`

### AI / Signals
- Models and feature plumbing:
  - `lib/services/mtm_models.dart` (load TFLite models from assets, inference helpers)
  - `lib/services/feature_builder.dart` (build 64×N feature sequences + indicators)
  - `lib/services/ai_service.dart` (fetch data, build features, call models, produce BUY/SELL/HOLD)
- Alternate/legacy inference (unused):
  - `lib/services/inference_service.dart` (typed tflite wrapper)
  - `lib/tflite/infer_service.dart` (older demo service)

### Config / Secrets
- `lib/screens/settings_screen.dart` → writes `TradingPrefs`
- `lib/src/core/trading_prefs.dart` → stores API key/secret, env (testnet/live), default quote
- `lib/models/app_settings.dart` + `lib/services/settings_store.dart` (unused path)

### Testing
- `test/widget_test.dart` placeholder
- `test/e2e/*` present (not mapped here; see test directory for specifics)

## 2) Swimlane Diagram (text)

```text
Binance Testnet/WebSocket
  │  (wss miniTicker, REST: klines, ticker)
  ▼
MarketData
  │  (parse, normalize closes/prices)
  ▼
Features
  │  (64×N sequence; SMA/RSI; fallback from ticker)
  ▼
AI Inference
  │  (direction prob, next return, volatility)
  ▼
Signal/Decision
  │  (BUY/SELL/HOLD thresholds)
  ▼
Risk/Constraints
  │  (minNotional clamp; scales)
  ▼
Paper Broker (Binance Testnet)
  │  (POST /api/v3/order)
  ▼
Portfolio/PNL
  │  (store order locally; display holdings)
  ▼
UI (Dashboard, Market, Details, Trade, Portfolio)
```

## 3) Arrow-by-Arrow Code Anchors

- Binance Testnet/WebSocket → MarketData
  - WebSocket connect and event handling:
    - `lib/services/price_stream.dart:24-41`
```24:41:lib/services/price_stream.dart
Future<void> _connect() async {
  final sym = symbol.toLowerCase();
  final uri = testnet
      ? Uri.parse('wss://testnet.binance.vision/ws/$sym@miniTicker')
      : Uri.parse('wss://stream.binance.com:9443/ws/$sym@miniTicker');
  _ch = IOWebSocketChannel.connect(uri.toString());
  _ch!.stream.listen((event) {
    final data = json.decode(event);
    final raw = (data is Map)
        ? (data['c'] ?? (data['data'] != null ? data['data']['c'] : null))
        : null;
    final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (v != null && !_controller.isClosed) _controller.add(v);
  }, ...);
}
```
  - REST market data (klines/ticker):
    - `lib/services/dio_binance_client.dart:133-149` (ticker)
    - `lib/services/dio_binance_client.dart:151-185` (klines)

- MarketData → Features
  - Build 64×N sequence from klines closes:
    - `lib/services/ai_service.dart:44-51` → map closes + `FeatureBuilder.sequenceFromCloses`
```44:51:lib/services/ai_service.dart
final kl = await client.klines(sym, '5m', limit: 128);
final closes = kl.map<double>((row) {
  final v = row[4];
  return (v as num).toDouble();
}).toList();
final seq = fb.sequenceFromCloses(closes, length: 64);
out = await models.predictAllFromSequence(seq);
```
  - Fallback single-tick features from ticker:
    - `lib/services/ai_service.dart:51-54`
    - `lib/services/feature_builder.dart:30-77` (indicators, padding)

- Features → AI Inference
  - Run models on sequence:
    - `lib/services/mtm_models.dart:102-110` (runSequence)
```102:110:lib/services/mtm_models.dart
Future<MtmOutput> runSequence(List<List<double>> seq) async {
  final input = [seq];
  final p = predictDirection(input);
  final r = predictReturn(input);
  final v = predictVolatility(input);
  return MtmOutput(p, r, v);
}
```

- AI Inference → Signal/Decision
  - Thresholding and packaging action:
    - `lib/services/ai_service.dart:55-63`
```55:63:lib/services/ai_service.dart
final double prob = (out.probUp ?? 0.5).toDouble();
final double nextR = (out.nextReturn ?? 0.0).toDouble();
final double vol = (out.volatility ?? 0.0).toDouble();
final action = prob >= 0.55 ? 'BUY' : (prob <= 0.45 ? 'SELL' : 'HOLD');
final double confidence = (prob * 100).clamp(0.0, 100.0).toDouble();
final double targetPrice = last * (1 + nextR);
final volatilityLabel = _volLabel(vol);
```

- Signal/Decision → Risk/Constraints
  - Pre-validate against min notional (quote clamp):
    - `lib/screens/trading_modal.dart:316-320` (clamp before order)
```316:320:lib/screens/trading_modal.dart
try {
  q = (await client.clampQuoteToMinNotional(sym, q)).toDouble();
} catch (_) {
  // continue with provided amount if clamp helper not available
}
```
  - Helper implementation:
    - `lib/services/dio_binance_client.dart:269-293` (minNotional + clamp)

- Risk/Constraints → Paper Broker (Binance Testnet)
  - Place market order by quote USDT:
    - `lib/services/dio_binance_client.dart:221-235` (signed POST)
```221:235:lib/services/dio_binance_client.dart
Future<Map<String, dynamic>> newMarketOrderQuote({
  required String symbol,
  required String side,
  required num quoteOrderQty,
}) async {
  final data = await _post('/api/v3/order', signed: true, query: {
    'symbol': _normSymbol(symbol),
    'side': side.toUpperCase(),
    'type': 'MARKET',
    'quoteOrderQty': quoteOrderQty,
    'newOrderRespType': 'RESULT',
  });
  return Map<String, dynamic>.from(data as Map);
}
```

- Paper Broker → Portfolio/PNL
  - Persist recent order locally:
    - `lib/screens/trading_modal.dart:326-336` (construct + add)
    - `lib/src/core/order_history.dart:65-75` (save to SharedPreferences)

- Portfolio/PNL → UI
  - Display holdings, mini chart with REST:
    - `lib/screens/portfolio_screen.dart:122-141` (holdings list tiles)
    - `lib/screens/portfolio_screen.dart:63-119` (mini chart)

## 4) Broken Links and Stale Code

- Unused/legacy services:
  - `lib/services/inference_service.dart` (not referenced by UI; `AIService` uses `MtmModels` directly)
  - `lib/tflite/infer_service.dart` (older demo; unused)
  - `lib/src/services/binance.dart` and `lib/src/core/binance_client.dart` (alternate clients; unused)
  - `lib/services/binance_client.dart` (abstract; unused)
  - `lib/services/settings_store.dart` (unused)
- UI not wired in main navigation:
  - `lib/ui/explain_page.dart`
  - `lib/src/app/app_scaffold.dart` and `lib/src/features/*` pages (alternate shell)
- Portfolio/PNL gaps:
  - No consumption of `DioBinanceClient.account()`; portfolio uses mocked holdings
  - No PnL aggregation based on executed orders or account balances
- Risk/Constraints gaps:
  - `lib/services/exchange_rules.dart` not used in order flow; minNotional handled via client helper only

## Ownership (suggested)
- Market Data (WebSocket/REST): Platform
- Trading/Orders: Platform
- Portfolio/PNL: Product + Platform
- AI/Signals: AI/ML
- UI: Product + Design
- Config/Secrets: Platform
- Testing: QA/Dev

## Definition of Done (per domain)

### UI
- Navigation covers Dashboard, Market, Details, Trade, Portfolio, Settings
- Error/empty states for network and AI failures
- Trading modal validates inputs and shows order results
- Responsive on mobile and desktop

### State
- `TradingPrefs` reads/writes API keys, env, fixed quote
- Order history persists and is loadable; provide a UI to view it
- Remove or wire `SettingsStore` or consolidate with `TradingPrefs`

### Market Data
- WebSocket reconnects with backoff; parses miniTicker reliably
- REST fallbacks for symbols not on testnet (graceful messages in UI)
- Klines/ticker parsing tolerant to string/number formats

### Trading / Orders
- Quote clamped to minNotional before POST
- Handles signed requests (key/secret required) with clear errors
- Support Limit/Stop-Loss (currently disabled in UI) or hide options until implemented
- Add order history screen to display filled/failed orders

### Portfolio / PnL
- Fetch account balances via `account()` on selected env
- Aggregate holdings value; compute daily PnL
- Reconcile with recent orders stored locally

### AI / Signals
- Models load (FP16 with FP32 fallback)
- Features built from klines; fallback to ticker features when klines unavailable
- Decision thresholds configurable; surface probabilities in UI
- Add Explainability view accessible from AI cards

### Config / Secrets
- Settings screen saves/loads keys, env, fixed quote
- Optionally encrypt secrets at rest or employ OS keychain
- Testnet/live toggle verified across data/trading flows

### Testing
- Widget tests for trading modal validation and error states
- Integration tests for AI service pipelines with mocked model outputs
- E2E: place a testnet market order and verify order history persistence

---

Notes:
- Default environment in `DioBinanceClient.createFromPrefs()` is Testnet until `TradingPrefs` is fully wired (see commented code). Consider enabling real prefs loading to respect user settings.








