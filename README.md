# MyTradeMate

### Deterministic harnesses
- `PriceStream` poate injecta o sursă de evenimente + `sleep` pentru teste deterministe.
- `AIService` expune `inferAndExplainForTest(...)` pentru a testa BUY/HOLD/SELL fără rețea.

### Navigation & State Management Audit
- App observes lifecycle: pauses/resumes price streams; screens use RestorationMixin unde are sens.
- Deterministic harness: PriceStream injectabil; AIService inferAndExplainForTest pentru teste offline.

Deterministic Flutter builds via FVM and CI health gates.

## Deterministic builds (FVM)

This repo uses FVM to pin Flutter SDK version (`.fvm/fvm_config.json`).

Bootstrap environment and fetch dependencies:

```bash
bash tool/bootstrap.sh
```

## Standard scripts

```bash
# Static analysis (fails on issues)
bash tool/analyze.sh

# Tests with coverage (fails if <60%)
bash tool/test.sh

# Release APK build (Linux CI)
bash tool/build.sh
```

Artifacts:
- Coverage: `coverage/lcov.info`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Environment variables (.env.sample)

Copy `env.sample` to `.env` locally and set values (testnet only). In CI, we use `--dart-define`.

```bash
cp env.sample .env
```

Sample keys:
```
BINANCE_API_KEY=
BINANCE_API_SECRET=
BINANCE_ENV=testnet
DEFAULT_QUOTE=50
```

At runtime you can pass these via `--dart-define` (used by `TradingPrefs` as fallbacks):

```bash
fvm flutter run \
  --dart-define=BINANCE_API_KEY=xxx \
  --dart-define=BINANCE_API_SECRET=yyy \
  --dart-define=BINANCE_ENV=testnet \
  --dart-define=DEFAULT_QUOTE=50
```

## CI

GitHub Actions workflow in `.github/workflows/ci.yml`:
- Analyzer must report 0 issues
- Tests must pass
- Coverage must be ≥ 60%
- Uploads `lcov.info` and APK as artifacts

## Portfolio & PnL (Testnet)
- Portofoliul citește `GET /api/v3/account` (testnet) și calculează totalul în USDT.
- Prețuri: `tickerPrice` pe perechi `ASSETUSDT` + cache în memorie.
- PnL zilnic: Δ vs. „ieri” (persistat în SharedPreferences).

### Rulare locală (testnet)
```
cp env.sample .env
# adaugă BINANCE_API_KEY/_SECRET

tool/bootstrap.sh
tool/analyze.sh
tool/test.sh    # raportează Coverage (cleaned core)
tool/build.sh
```

### Explainability
- Buton **Explain** pe AI cards → deschide ExplainPage cu: Prob↑, Next Return, Volatility (+ label), și un snapshot din features (64×N).
- Teste: `test/ui/explain_mapping_test.dart`, `test/ui/explain_page_smoke_test.dart`.

### WS Backoff
- `PriceStream` reconectează cu 1s, 2s, 5s, 10s, 20s, 30s și circuit breaker după 6 erori consecutive.
- Helperi testați: `backoffForAttempt()`, `shouldTripCircuit()`.

Comenzi utile
```
tool/analyze.sh
tool/test.sh        # țintă: Coverage (cleaned core) ≥ 60%
tool/build.sh
```

În PR, atașează:
- tail analyzer (0 issues)
- tail tests (durată + “Coverage (cleaned core): … (LH/LF)”) 
- mărimea APK
- lista dif-urilor
