## Red Team Plan and Status

Harness
- ScriptedEventSource: deterministic WS source that replays scripted/fixture events with `delay_ms`, `close`, `error`, `end` sentinel.
- Anti-flake measures: end sentinel, concurrency=1, teardown drain (`dispose` + `close` + `drainMicrotasks()`), bounded reconnects (`maxReconnects`, `reconnectBackoff`).
- Runner: `tool/red_team.sh` executes all tests in `test/red_team`.

How to run
```bash
bash tool/red_team.sh
# Single test with expanded logs
flutter test test/red_team/market_data_ws_flaps_test.dart --concurrency=1 --reporter=expanded
```

Completed scenario (✅)
- WS flaps (reconnects bounded; no duplicate emissions)
  - Test: `test/red_team/market_data_ws_flaps_test.dart`
  - Script: inline script with `tick(1000) → close → tick(1001) → spike(1015) → end`
  - Service: `MarketDataServiceImpl.test(...)` with small throttle/poll intervals
  - Asserts: order preserved; spike present; `src.connects <= 3`; no consecutive duplicates
  - Teardown: `await svc.dispose(); await src.close(); await drainMicrotasks();`

Anti-flake checklist (applied)
1) Add `{"end": true}` sentinel to stop stream deterministically
2) Run with `--concurrency=1`
3) Teardown drains: `dispose()` + `close()` + small `Future.delayed` + `drainMicrotasks()`
4) Small but nonzero `delay_ms` steps in script for stable ordering
5) Limit reconnect attempts (`maxReconnects = 1`; optional longer `reconnectBackoff`)
6) Optional after-emission settle before asserts (5–10ms + `drainMicrotasks()`)

If a flake appears
- Increase the reconnect step `delay_ms` by +5–20ms
- Increase `reconnectBackoff` or set `maxReconnects=1`
- Add a tiny settle after the last expected tick
- Ensure teardown awaits all disposals and drains
- Run single test with `--timeout=60s --reporter=expanded` to inspect logs

Planned scenarios (backlog)
- Precision mismatch and zero-liquidity candle
- Extreme wick triggers (stop/stop-limit edge)
- Time desync; calibration missing/corrupt fallback
- Risk cap exceeded (pre-trade violation surfaces)

References
- Market data service: `lib/services/market_data_service.dart`
- WS source/mocks: `test/mocks/binance_mocks.dart`
- Test helpers: `test/_helpers/test_market_data.dart`
- Runner: `tool/red_team.sh`



