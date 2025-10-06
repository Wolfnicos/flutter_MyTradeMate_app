## Why cleaned-core?

We enforce coverage only on the **core and service modules** (`lib/src/core`, `lib/services`, `lib/models`).  
These modules drive trading logic, risk checks, AI inference, and broker execution — where correctness is critical.  

UI, widget, and E2E tests are valuable but inherently more flaky (timing, platform, network).  
By focusing the coverage gate on cleaned-core, we ensure robust test quality for the parts of the system that make real trading decisions, without blocking CI on fragile UI smoke tests.

## TestCoverage

### Overview

We enforce a cleaned-core coverage gate in CI to keep the critical logic well-tested while avoiding noise from UI and glue code. The gate currently runs via `tool/test.sh` and fails the job if cleaned-core coverage is below the configured threshold.

- Current cleaned-core coverage: see CI logs for the exact % on each run (printed near the end as `Coverage (cleaned core): …`). Recent local runs show around ~72–73%.
- Default gate: >= 60% (configurable via `COVERAGE_GATE`).

### What “cleaned-core” includes

The coverage set focuses on core logic:

- `lib/services/**` (e.g., AI service, market data, paper broker, calibration, risk, trade coordinator, exchange client)
- `lib/src/core/**`
- `lib/models/**`

Excluded (via lcov filtering):

- UI layers (e.g., `lib/screens/**`, `lib/ui/**`, widgets)
- App/bootstrap (e.g., `main.dart`, routing)
- Generated code and platform shims
- Any file patterns not explicitly included above

Test discovery also skips `test/_skipped/**` by default to avoid flaky/long-running tests in CI.

### How coverage is computed

`tool/test.sh` runs the full suite (single-threaded for stability), then:

1. Generates a raw `coverage/lcov.info`.
2. Extracts only the cleaned-core paths.
3. Prints a summary and enforces the gate.
4. Fails strictly if the cleaned-core trace is empty (`LF=0`), to catch mis-configured patterns.

Notes:

- We pass `--ignore-errors unused,empty` to lcov to be robust to platform/file differences.
- If extract yields 0 files, the script aborts with a clear message and hints.

### How to run locally

Full suite + coverage (default UI tests off):

```bash
bash tool/test.sh
```

With UI tests enabled:

```bash
RUN_UI=1 bash tool/test.sh
```

One-by-one file execution (useful for debugging):

```bash
RUN_PER_FILE=1 bash tool/test.sh
```

Adjust the gate temporarily:

```bash
COVERAGE_GATE=70 bash tool/test.sh
```

Example output line near the end:

```text
Coverage (cleaned core): 72.7% (999/1374)
```


### Deterministic fixtures and mocks for WS/REST

- WebSocket tests use `ScriptedEventSource` with JSON fixtures under `test/fixtures/binance_ws/` (e.g., `burst_spike_gap.json`, `reconnect_then_resume.json`) for reproducible timing and reconnects.
- REST paths use `BinanceClientMock` to script ticker/klines and inject failures (e.g., timeouts, 502, auth errors) deterministically.
- Patterns: per-test timeout (~5–6s), concurrency=1, seed fixed, and teardown with `await svc.dispose(); await pumpEventQueue();` (or `await drainMicrotasks()`) to avoid lingering timers.
- WS tests are fixture-driven and use `reconnectBackoff` + `drained` for synchronization; no sleeps.


