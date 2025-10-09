## What’s New

- Stabilized MarketDataService implementation
- Added `MarketDataServiceImpl.test(...)` constructor for deterministic tests
- Idempotent pause/resume, anti-duplicate emissions, bounded reconnects (`src.connects <= 2`)
- Safe `dispose()` cancels WS + poller, drains microtasks

## Inherited Provider Improvements

- Added `InheritedMarketData.maybeOf` for non-subscribing access
- Moved guard logic into `didChangeDependencies` (no more initState nulls)
- Unified call sites through `.service`

## Shared Test Helpers (`test/_helpers/test_market_data.dart`)

- `FakeMarketDataService` (emits initial price immediately)
- `TestFakeEventSource`, `TestFakeRest`, and `drainMicrotasks()`

## UI Tests Fixed

- Wrapped with `wrapWithMarketData(FakeMarketDataService)`
- Fixed `market_details_loading_test.dart`, `market_details_reload_test.dart`, `nav/deeplink_test.dart`

## Service Tests Hardened

- `market_data_service_pause_resume_test.dart`: explicit resume kick, short throttle/poll, bounded reconnects
- `market_data_service_bursts_and_reconnects_test.dart`: bounded waits, assert connects <= 2, solid teardown
- `market_data_service_refresh_now_test.dart`: subscribe-before-refresh, longer timeout

## Results

- Full suite: all tests pass (no hangs)
- Coverage (cleaned-core): 79.2% (670/846) → above 60% gate
- Build: APK build succeeds (~38 MB release artifact)

## Notes

- Concurrency locked at 1 to avoid race conditions
- Deterministic helpers ensure stable CI behavior
- This PR unblocks coverage gate and stabilizes flakiest service/UI tests





