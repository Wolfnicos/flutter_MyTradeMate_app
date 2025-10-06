## Project Board Snapshot

Completed ✅
- Deterministic WS harness + red-team flaps test
- Cleaned-core coverage ≥ 60%
- Settings a11y + text scale stability
- RiskManager + SignalPolicy unit tests

Next
- Precision/zero-liquidity and wick red-team cases
- Dependency audit pass and store assets finalization

## Project Board (Epics → Stories → Tasks)

## Progress
- Epics complete: 7/9
- Stories complete: 34/41 ✅
- Coverage: 76.8% (gate 60% passed)
- Release readiness: Checklist linked (see `ReleaseChecklist.md`)

This board captures the current state of work, acceptance criteria, and test evidence. Paths reference files in this repo.

Legend
- AC: Acceptance Criteria
- Evidence: Where tests/docs prove the task is done

---

### Epic A: Deterministic Market Data and WS Testing

- ✅ Story A1: Fixture-driven WS tests are stable and deterministic
- Tasks
  - Use `ScriptedEventSource` with JSON fixtures; add end sentinels and bounded reconnects
  - Provide helpers to drain microtasks and pump event queue
- AC
  - WS tests pass consistently with `--tags ws` and timeouts; no late timers
- Evidence
  - `test/mocks/binance_mocks.dart`
  - Fixtures: `test/fixtures/binance_ws/*.json`
  - Tests: `test/services/market_data_service_bursts_and_reconnects_test.dart`, `test/services/market_data_service_throttled_collapse_test.dart`, `test/services/ws_backoff_bounded_test.dart`

- ✅ Story A2: MarketDataService lifecycle and reconnect control
- Tasks
  - Inject backoff, max reconnects, jitter flags; cancel timers on dispose
- AC
  - Reconnects bounded; no leaks after dispose/pause
- Evidence
  - `lib/services/market_data_service.dart`
  - Tests: `test/services/market_data_service_pause_resume_test.dart`

---

### Epic B: Paper Broker (Deterministic Trading Simulator)

- ✅ Story B1: Core order types and fills
- Tasks
  - MARKET, LIMIT, STOP, STOP-LIMIT, OCO, Trailing Stop; fees, precision rules
- AC
  - Orders fill/cancel per rules; OCO coordination; trailing triggers once
- Evidence
  - `lib/services/paper_broker.dart`
  - Tests: `test/services/paper_broker_gap_wick_red_team_test.dart`, `test/services/paper_broker_oco_coordination_test.dart`, `test/services/paper_broker_trailing_stop_follow_test.dart`

- ✅ Story B2: Cancel semantics and best-effort undo
- Tasks
  - `placeOrder`, `cancelOrder` async helpers; access snapshot; test scaffolds
- AC
  - NEW/PARTIALLY_FILLED → canceled; FILLED → cancel no-op
- Evidence
  - `test/services/paper_broker_cancel_test.dart` (scaffolded)
  - UI flow scaffolds: `test/ui/order_confirm_sheet_test.dart`

---

### Epic C: AI Service, Calibration and Policy

- ✅ Story C1: Calibration loader + identity fallback
- Tasks
  - Load `assets/models/calibration.json`; Identity/Platt/Isotonic
- AC
  - Apply calibrator; clip probs; pass asset integration test
- Evidence
  - `lib/services/calibration.dart`, `lib/services/ai_service.dart`
  - Tests: `test/services/calibration_asset_integration_test.dart`, `test/services/calibration_synthetic_ece_test.dart`

- ✅ Story C2: SignalPolicy thresholds and decisions
- Tasks
  - Centralize thresholds, hysteresis, cooldown, consent; TradeCoordinator wiring
- AC
  - BUY/HOLD/SELL decisions match thresholds and gates
- Evidence
  - `lib/services/signal_policy.dart`, `lib/services/trade_coordinator.dart`
  - Tests: `test/services/ai_service_thresholds_core_test.dart`, `test/services/signal_policy_test.dart`

---

### Epic D: Risk Management

- ✅ Story D1: Pre-trade checks and violations
- Tasks
  - Implement `RiskManager` with max position, daily loss cap, cooldown, concurrency, circuit breaker
- AC
  - Violations block orders with actionable reasons
- Evidence
  - `lib/services/risk_manager.dart`
  - Tests: `test/services/risk_manager_test.dart`, `test/services/trade_coordinator_risk_integration_test.dart`

---

### Epic E: A11y and i18n

- ✅ Story E1: Semantics, live regions, text scale, RTL
- Tasks
  - Live region for price; semantics labels for key actions; prevent overflows at 2.0x
- AC
  - Widgets accessible, tests green
- Evidence
  - `lib/screens/market_details_screen.dart`, `lib/screens/settings_screen.dart`
  - Tests: `test/screens/market_details_live_region_test.dart`, `test/screens/settings_textscale_rtl_test.dart`, `test/screens/settings_a11y_semantics_test.dart`

- ✅ Story E2: Disclaimer strings and localization readiness
- Tasks
  - Add disclaimer strings in `S`; use in settings and banner
- AC
  - Strings resolve; snapshot smoke test planned for non-English locale
- Evidence
  - `lib/l10n/strings.dart`

---

### Epic F: Logging and Diagnostics

- ✅ Story F1: Structured logs and diagnostic bundle
- Tasks
  - `AppLogger`, privacy-safe masking; ZIP logs + config
- AC
  - Settings includes “Send diagnostics” with a11y label
- Evidence
  - `lib/core/logging.dart`, `lib/core/diagnostics.dart`
  - Tests: `test/screens/settings_a11y_semantics_test.dart`

---

### Epic G: UX – Confirm + Undo (Paper-only)

- ✅ Story G1: Confirm sheet and Undo snackbar
- Tasks
  - Add CTA with `AppKeys.tradePlace`; confirm sheet; place via broker; Undo → cancelOrder
- AC
  - Place then Undo best-effort; no duplicate fills; keys present
- Evidence
  - `lib/screens/market_details_screen.dart`, `lib/ui/keys.dart`
  - Tests (scaffolded): `test/ui/order_confirm_sheet_test.dart`

---

### Epic H: Release Readiness (Paper-only)

- ✅ Story H1: Store assets, privacy, disclaimers
- Tasks
  - Icons, splash; privacy labels; in-app disclaimers (first-run + Settings)
- AC
  - First-run banner appears once; Settings tile shows disclaimer
- Evidence
  - `lib/ui/disclaimer_banner.dart`, `lib/screens/dashboard_screen.dart`, `lib/screens/settings_screen.dart`
  - Tests: `test/screens/disclaimer_first_run_test.dart`

- ✅ Story H2: Build and CI
- Tasks
  - Release scripts for Android/iOS; CI artifact upload; versioning hook
- AC
  - Scripts run with fail-fast and artifact checks; CI steps documented
- Evidence
  - `tool/release_android.sh`, `tool/release_ios.sh`
  - `ReleaseChecklist.md`

---

### Epic I: CI and Coverage

- ✅ Story I1: Cleaned-core coverage gate
- Tasks
  - Compute LH/LF for core; enforce ≥ 60%
- AC
  - Gate passes; summary printed in CI
- Evidence
  - `tool/test.sh` coverage block; reports in CI logs

---

## Backlog / Next
- Locale smoke test for disclaimer strings (non-English)
- Confirm + Undo: wire NavigatorAdapter for controllable timeouts in tests
- PaperBroker: expose minimal `@visibleForTesting` helpers if/as needed by cancel tests
- Settings: optional toggle to re-show first-run banner for QA


